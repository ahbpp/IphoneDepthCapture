
import argparse
import json
import os

from PIL import Image, ExifTags


def extract_json_metadata_from_png(png_path):
    # Open the PNG file
    with Image.open(png_path) as img:

        # Extract the JSON string from the 'Description' field
        json_data_str = img.getxmp()['xmpmeta']['RDF']['Description']["description"]['Alt']['li']['text']
        
        if json_data_str is None:
            print("No JSON metadata found in the 'Description' field.")
            return None
        
        # Convert JSON string back to a dictionary
        json_data = json.loads(json_data_str)

        exif_data = {ExifTags.TAGS[k]: v for k, v in img._getexif().items() if k in ExifTags.TAGS}
        json_data["exif"] = exif_data
        return json_data




# Use the function to extract metadata
# metadata = extract_json_metadata_from_png("/Users/alekseikarpov/Downloads/frame_2_depthImage.png")
# print(metadata)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Extract metadata from a PNG file.')
    parser.add_argument('--png_path', '-f', type=str, help='The path to the PNG file.')
    args = parser.parse_args()

    if os.path.isdir(args.png_path):
        for file in os.listdir(args.png_path):
            if file.endswith(".png"):
                metadata = extract_json_metadata_from_png(args.png_path + "/" + file)
                print(metadata)
    else:
        metadata = extract_json_metadata_from_png(args.png_path)
        print(metadata)
