import os
import re
import shutil
import sys

def process_markdown(posts_dir, attachments_dir, static_images_dir):
    # Step 1: Process each markdown file in the posts directory
    for filename in os.listdir(posts_dir):
        if filename.endswith(".md"):
            filepath = os.path.join(posts_dir, filename)
            
            with open(filepath, "r") as file:
                content = file.read()
            
            # Step 2: Find all image links in the format [[image.png]]
            images = re.findall(r'\[\[([^]]*\.png)\]\]', content)
            
            # Step 3: Replace image links and ensure URLs are correctly formatted
            for image in images:
                # Markdown-compatible link
                markdown_image = f"![Image Description](/images/{image.replace(' ', '%20')})"
                content = content.replace(f"[[{image}]]", markdown_image)
                
                # Step 4: Copy the image to the Hugo static/images directory if it exists
                image_source = os.path.join(attachments_dir, image)
                if os.path.exists(image_source):
                    shutil.copy(image_source, static_images_dir)

            # Step 5: Write the updated content back to the markdown file
            with open(filepath, "w") as file:
                file.write(content)

    print("✅ Markdown files processed and images copied successfully.")

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python images.py <posts_dir> <attachments_dir> <static_images_dir>")
        sys.exit(1)

    posts_dir = sys.argv[1]
    attachments_dir = sys.argv[2]
    static_images_dir = sys.argv[3]

    process_markdown(posts_dir, attachments_dir, static_images_dir)
