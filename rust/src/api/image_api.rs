use flutter_rust_bridge::frb;
use base64::{Engine as _, engine::general_purpose::STANDARD as BASE64};
use image::RgbaImage;

/// 图片信息
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ImageInfo {
    pub width: u32,
    pub height: u32,
    pub format: String, // "png", "jpg", "gif", etc.
}

/// 获取图片信息（宽高、格式）
/// 参数：base64 编码的图片数据
/// 返回：图片信息 JSON 字符串
#[frb]
pub fn get_image_info(image_data_base64: String) -> anyhow::Result<String> {
    let image_bytes = BASE64.decode(&image_data_base64)?;
    let format = image::guess_format(&image_bytes)?;
    let img = image::load_from_memory(&image_bytes)?;
    
    let info = ImageInfo {
        width: img.width(),
        height: img.height(),
        format: format.extensions_str()[0].to_string(),
    };
    
    Ok(serde_json::to_string(&info)?)
}

/// 解码图片并重新排列行
/// 参数：
/// - image_data_base64: base64 编码的图片数据
/// - rows: 要分割的行数
/// 返回：重新排列后的图片数据（base64 编码的 PNG）
#[frb]
pub fn rearrange_image_rows(image_data_base64: String, rows: u32) -> anyhow::Result<String> {
    tracing::debug!("[Image API] rearrange_image_rows called with rows: {}, image size: {} bytes", rows, image_data_base64.len());
    
    let image_bytes = BASE64.decode(&image_data_base64)?;
    tracing::debug!("[Image API] Decoded image bytes: {} bytes", image_bytes.len());
    
    let src = image::load_from_memory(&image_bytes)?;
    
    let width = src.width();
    let height = src.height();
    let remainder = height % rows;
    
    tracing::info!("[Image API] Image dimensions: {}x{}, rows: {}, remainder: {}", width, height, rows, remainder);
    
    // 转换为 RGBA
    let src_rgba = src.to_rgba8();
    
    // 创建目标图像缓冲区
    let mut dst = RgbaImage::new(width, height);
    
    // 复制图像块的辅助函数
    let mut copy_image_block = |src_start_y: u32, dst_start_y: u32, block_height: u32| {
        for y in 0..block_height {
            for x in 0..width {
                let pixel = src_rgba.get_pixel(x, src_start_y + y);
                dst.put_pixel(x, dst_start_y + y, *pixel);
            }
        }
    };
    
    // 重新排列行（参考原版逻辑）
    for x in 0..rows {
        let mut copy_h = height / rows;
        let mut py = copy_h * x;
        let y = height - (copy_h * (x + 1)) - remainder;
        
        if x == 0 {
            copy_h += remainder;
        } else {
            py += remainder;
        }
        
        copy_image_block(y, py, copy_h);
    }
    
    // 编码为 PNG
    let mut png_data = Vec::new();
    {
        let mut encoder = png::Encoder::new(&mut png_data, width, height);
        encoder.set_color(png::ColorType::Rgba);
        encoder.set_depth(png::BitDepth::Eight);
        let mut writer = encoder.write_header()?;
        writer.write_image_data(dst.as_raw())?;
    }
    
    // 转换为 base64
    let base64_result = BASE64.encode(&png_data);
    tracing::info!("[Image API] Image rearranged successfully, output size: {} bytes", base64_result.len());
    Ok(base64_result)
}

/// 裁剪图片
/// 参数：
/// - image_data_base64: base64 编码的图片数据
/// - x, y: 裁剪起始坐标
/// - width, height: 裁剪区域的宽高
/// 返回：裁剪后的图片数据（base64 编码的 PNG）
pub fn crop_image(image_data_base64: String, x: u32, y: u32, width: u32, height: u32) -> anyhow::Result<String> {
    let image_bytes = BASE64.decode(&image_data_base64)?;
    let img = image::load_from_memory(&image_bytes)?;
    
    // 确保裁剪区域在图片范围内
    let img_width = img.width();
    let img_height = img.height();
    
    if x + width > img_width || y + height > img_height {
        return Err(anyhow::anyhow!(
            "Crop area ({},{},{},{}) exceeds image bounds ({}x{})",
            x, y, width, height, img_width, img_height
        ));
    }
    
    // 裁剪图片
    let cropped = img.crop_imm(x, y, width, height);
    
    // 编码为 PNG
    let mut png_data = Vec::new();
    {
        let rgba = cropped.to_rgba8();
        let mut encoder = png::Encoder::new(&mut png_data, width, height);
        encoder.set_color(png::ColorType::Rgba);
        encoder.set_depth(png::BitDepth::Eight);
        let mut writer = encoder.write_header()?;
        writer.write_image_data(rgba.as_raw())?;
    }
    
    Ok(BASE64.encode(&png_data))
}

/// 垂直拼接多张图片
/// 参数：
/// - image_data_base64_list: JSON 数组字符串，包含多个 base64 编码的图片数据
/// 返回：拼接后的图片数据（base64 编码的 PNG）
pub fn compose_vertical(image_data_base64_list: String) -> anyhow::Result<String> {
    // 解析 JSON 数组
    let image_list: Vec<String> = serde_json::from_str(&image_data_base64_list)?;
    
    if image_list.is_empty() {
        return Err(anyhow::anyhow!("Image list is empty"));
    }
    
    // 加载所有图片
    let mut images = Vec::new();
    let mut total_height = 0u32;
    let mut max_width = 0u32;
    
    for base64_data in &image_list {
        let image_bytes = BASE64.decode(base64_data)?;
        let img = image::load_from_memory(&image_bytes)?;
        total_height += img.height();
        max_width = max_width.max(img.width());
        images.push(img);
    }
    
    // 创建目标图像
    let mut result = RgbaImage::new(max_width, total_height);
    
    // 垂直拼接
    let mut current_y = 0u32;
    for img in images {
        let rgba = img.to_rgba8();
        let width = rgba.width();
        let height = rgba.height();
        
        for y in 0..height {
            for x in 0..width {
                let pixel = rgba.get_pixel(x, y);
                result.put_pixel(x, current_y + y, *pixel);
            }
        }
        
        current_y += height;
    }
    
    // 编码为 PNG
    let mut png_data = Vec::new();
    {
        let mut encoder = png::Encoder::new(&mut png_data, max_width, total_height);
        encoder.set_color(png::ColorType::Rgba);
        encoder.set_depth(png::BitDepth::Eight);
        let mut writer = encoder.write_header()?;
        writer.write_image_data(result.as_raw())?;
    }
    
    Ok(BASE64.encode(&png_data))
}
