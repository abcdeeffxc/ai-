import stable_diff
stable_diff.generate_image_by_qiuye(
    prompt=f"King Yao, historical legend style, standing on a high hill, frowning and looking at the flood, people struggling in the flood, panoramic view, 8k, photorealistic",
    negative_prompt = "lowres, blurry, ugly, duplicate, text, watermark, extra limbs, bad hands",
    model_name="cyberrealistic_v40.safetensors",
    steps = 20
    )