from google import genai
from google.genai import types
import argparse
import json
import os
from datetime import datetime

PROJECT_ID = "gcp-watchtower-peak"
LOCATION = "global"

client = genai.Client(vertexai=True, project=PROJECT_ID, location=LOCATION)
MODELS = {
    "flash": "gemini-2.5-flash-image",
    "pro": "gemini-3-pro-image-preview",
}

LOGFILE = "output/generation_log.jsonl"

def log_generation(model, prompt, output_paths):
    os.makedirs(os.path.dirname(LOGFILE) or ".", exist_ok=True)
    entry = {
        "date": datetime.now().isoformat(),
        "model": model,
        "prompt": prompt,
        "output_images": output_paths,
    }
    with open(LOGFILE, "a") as f:
        f.write(json.dumps(entry) + "\n")

def main():
    parser = argparse.ArgumentParser(description="Generate images using Gemini")
    parser.add_argument("-p", "--prompt", required=True, help="The prompt for image generation")
    parser.add_argument("-o", "--output", default="output/output.png", help="Output filename (default: output/output.png)")
    parser.add_argument("-m", "--model", choices=["flash", "pro"], default="flash", help="Model to use (default: flash)")
    parser.add_argument("-i", "--input", help="Reference image path for image-to-image generation")
    parser.add_argument("-n", "--num-images", type=int, default=1, help="Number of images to generate (default: 1)")
    parser.add_argument("--aspect-ratio", default="16:9", help="Aspect ratio (default: 16:9, e.g. 1:1, 4:3)")
    args = parser.parse_args()

    # Build contents with optional reference image
    if args.input:
        with open(args.input, "rb") as f:
            image_data = f.read()
        mime_type = "image/png" if args.input.endswith(".png") else "image/jpeg"
        contents = [
            types.Part(inline_data=types.Blob(mime_type=mime_type, data=image_data)),
            args.prompt,
        ]
    else:
        contents = args.prompt

    model_id = MODELS[args.model]
    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    base, ext = os.path.splitext(args.output)

    generated_images = []
    for i in range(args.num_images):
        response = client.models.generate_content(
            model=model_id,
            contents=contents,
            config=types.GenerateContentConfig(
                response_modalities=['IMAGE', 'TEXT'],
                image_config=types.ImageConfig(
                    aspect_ratio=args.aspect_ratio,
                    image_size="2K",
                ),
            ),
        )

        # Check for errors if an image is not generated
        if response.candidates[0].finish_reason != types.FinishReason.STOP:
            reason = response.candidates[0].finish_reason
            print(f"Image {i+1}: Prompt Content Error: {reason}")
            continue

        output_path = f"{base}_{i+1}{ext}" if args.num_images > 1 else args.output
        for part in response.candidates[0].content.parts:
            if part.thought:
                continue
            if part.inline_data:
                with open(output_path, "wb") as f:
                    f.write(part.inline_data.data)
                print(f"Image saved to {output_path}")
                generated_images.append(output_path)

    if generated_images:
        log_generation(model_id, args.prompt, generated_images)

if __name__ == "__main__":
    main()
