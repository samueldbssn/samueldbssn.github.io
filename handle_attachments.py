import os
import re
import shutil
import sys
import urllib.parse

VALID_IMAGE_EXTENSIONS = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".bmp")
VALID_FILE_EXTENSIONS = (".pdf",)

def ensure_directory(path):
    os.makedirs(path, exist_ok=True)

def add_or_replace_title(content, title):
    lines = content.splitlines()
    if not (lines and lines[0].strip() == "---"):
        return content  

    end_index = None
    for i, line in enumerate(lines[1:], start=1):
        if line.strip() == "---":
            end_index = i
            break

    if end_index is None:
        return content 

    has_title = False
    for i in range(1, end_index):
        if lines[i].lower().startswith("title:"):
            lines[i] = f'Title: "{title}"'
            has_title = True
            break

    if not has_title:
        lines.insert(end_index, f'Title: "{title}"')

    return "\n".join(lines)

def convert_internal_links(content, attachments_dir, target_dir, extensions, web_path, embed_type):
    updated_content = content
    matched_files = re.findall(r'\[\[([^]]+\.(?:' + "|".join(ext[1:] for ext in extensions) + r'))\]\]', content, flags=re.IGNORECASE)
    
    for filename in matched_files:
        encoded = urllib.parse.quote(filename)

        if embed_type == "image":
            replacement = f"![Image]({web_path}/{encoded})"
        elif embed_type == "pdf":
            replacement = f"[Voir le PDF]({web_path}/{encoded})"
        else:
            replacement = f"[Télécharger le fichier]({web_path}/{encoded})"

        updated_content = updated_content.replace(f"[[{filename}]]", replacement)

        src = os.path.join(attachments_dir, filename)
        if os.path.exists(src):
            shutil.copy(src, target_dir)
        else:
            print(f"⚠️ File not found: {src}")
    
    return updated_content

def process_file(filepath, attachments_dir, img_dir, file_dir, destination_path):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    if "draft: true" in content:
        print(f"⏩ Skipping draft: {filepath}")
        return

    # Get the title from the filename (if needed, or extract a title based on filename)
    title = os.path.splitext(os.path.basename(filepath))[0]

    # Add or replace the title in the front matter
    content = add_or_replace_title(content, title)

    post_slug = os.path.splitext(os.path.basename(filepath))[0]
    final_dir = os.path.join(destination_path, post_slug)

    # Handle thumbnail if present
    content = handle_thumbnail(content, attachments_dir, final_dir)

    # Convert internal links to markdown links
    content = convert_internal_links(content, attachments_dir, img_dir, VALID_IMAGE_EXTENSIONS, "/images", embed_type="image")
    content = convert_internal_links(content, attachments_dir, file_dir, VALID_FILE_EXTENSIONS, "/files", embed_type="pdf")

    ensure_directory(final_dir)

    with open(os.path.join(final_dir, "index.md"), "w", encoding="utf-8") as f:
        f.write(content)

def handle_thumbnail(content, attachments_dir, post_path):
    # Extract the thumbnail filename from the front matter (e.g., [[Leibniz.png]])
    match = re.search(r'thumbnail:\s*\"\[\[([^\]]+)\]\]\"', content)
    
    if match:
        thumbnail_filename = match.group(1)  

        # Check if the thumbnail file exists in the attachments directory
        src_thumbnail_path = os.path.join(attachments_dir, thumbnail_filename)
        
        if os.path.exists(src_thumbnail_path):
            
            # Copy the thumbnail file to the post folder
            [_, ext] = thumbnail_filename.rsplit('.', 1)

            dest_thumbnail_path = os.path.join(post_path, f"featured.{ext}")
            shutil.copy(src_thumbnail_path, dest_thumbnail_path)
            
            # Update the front matter with the correct image path in the Hugo static folder
            updated_thumbnail_path = f"/images/{os.path.basename(thumbnail_filename)}"
            content = re.sub(r'thumbnail:\s*\[\[([^\]]+)\]\]', f'thumbnail: "{updated_thumbnail_path}"', content)
        else:
            print(f"⚠️ Thumbnail file not found: {src_thumbnail_path}")
    
    return content

def process_all(posts_dir, attachments_dir, img_dir, file_dir, destination_path):
    ensure_directory(img_dir)
    ensure_directory(file_dir)

    for filename in os.listdir(posts_dir):
        if filename.endswith(".md"):
            filepath = os.path.join(posts_dir, filename)
            process_file(filepath, attachments_dir, img_dir, file_dir, destination_path)

    print("✅ All files processed.")

if __name__ == "__main__":
    if len(sys.argv) != 6:
        print("Usage: python images.py <posts_dir> <attachments_dir> <static_images_dir> <static_files_dir> <destination_path>")
        sys.exit(1)

    posts_dir, attachments_dir, static_images_dir, static_files_dir, destination_path = sys.argv[1:6]
    process_all(posts_dir, attachments_dir, static_images_dir, static_files_dir, destination_path)

