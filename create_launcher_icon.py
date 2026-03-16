from PIL import Image
import os

# Create a properly sized launcher icon
def create_launcher_icon():
    try:
        # Open the original SHA icon
        original = Image.open("assets/icon/sha_icon.jpeg")
        
        # Create a new 512x512 image with white background
        launcher_icon = Image.new('RGB', (512, 512), 'white')
        
        # Resize the original to fit with padding (80% of the size)
        target_size = int(512 * 0.8)  # 80% of 512 = 409
        original_resized = original.resize((target_size, target_size), Image.Resampling.LANCZOS)
        
        # Calculate position to center the image
        x = (512 - target_size) // 2
        y = (512 - target_size) // 2
        
        # Paste the resized image onto the white background
        launcher_icon.paste(original_resized, (x, y))
        
        # Save the new launcher icon
        launcher_icon.save("assets/icon/launcher_icon.png", "PNG")
        print("Launcher icon created successfully!")
        
    except Exception as e:
        print(f"Error creating launcher icon: {e}")

if __name__ == "__main__":
    create_launcher_icon()