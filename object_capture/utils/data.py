import os
import typing as tp
import json
import numpy as np
import open3d as o3d
import cv2


from PIL import Image



def read_data(data_folder: str, mask_futher=1.1) -> tp.List[tp.Dict[str, tp.Any]]:
    """
    Reads the data for all frames in the specified folder.

    Args:
        data_folder (str): Path to the folder containing the object data.

    Returns:
        list: A list of dictionaries, each containing a frame's color image, depth image, and metadata.
    """
    frames = []

    # Find all unique frame IDs by scanning filenames
    frame_ids = set()
    for file_name in os.listdir(data_folder):
        if file_name.startswith("frame_"):
            frame_id = file_name.split('_')[1]
            frame_ids.add(frame_id)

    # Process each frame ID and load its associated files
    for frame_id in sorted(frame_ids, key=int):        
        # Define expected file names
        color_image_path = os.path.join(data_folder, f"frame_{frame_id}_colorImage.jpg")
        depth_image_path = os.path.join(data_folder, f"frame_{frame_id}_depthImage.png")
        metadata_path = os.path.join(data_folder, f"frame_{frame_id}_metadata.json")
        metadata = json.load(open(metadata_path))
        min_depth = metadata['minDepth']
        max_depth = metadata['maxDepth']
        assert min_depth == 0, "Min depth is not 0"
        assert max_depth == 2, "Max depth is not 2"
        
        depth = np.array(Image.open(depth_image_path)).astype(np.uint16)
        depth_scale = 255 / (max_depth - min_depth)
        # print(int(min_depth * depth_scale), min_depth, max_depth, depth_scale)
        depth += int(min_depth * depth_scale)
        depth_mask = (depth / depth_scale) > mask_futher
        d_height, d_width = depth.shape
        
        image = np.array(Image.open(color_image_path).resize((d_width, d_height), Image.Resampling.BILINEAR))
        depth = np.where(depth_mask, 0, depth)
        image = np.where(depth_mask[..., None], 0, image)

        # print(image.size, depth.shape)
        image = cv2.rotate(image, cv2.ROTATE_90_CLOCKWISE)
        depth = cv2.rotate(depth, cv2.ROTATE_90_CLOCKWISE)
        print(image.size, depth.shape)


        # Create the RGBDImage
        rgbd_image = o3d.geometry.RGBDImage.create_from_color_and_depth(
            color=o3d.geometry.Image(image),
            depth=o3d.geometry.Image(depth),
            depth_scale=depth_scale,  # Adjust scale as necessary
            depth_trunc=max_depth + 0.1,  # Set maximum depth threshold
            convert_rgb_to_intensity=False
        )

                # Extract camera intrinsics
        K = np.array(metadata['cameraIntrinsics']).T
        K[0, :] *= d_width / metadata['cameraReferenceDimensions']['width']
        K[1, :] *= d_height / metadata['cameraReferenceDimensions']['height']
        fy, fx = K[0, 0], K[1, 1]
        cy, cx = K[0, 2], K[1, 2]
        # Create the PinholeCameraIntrinsic object
        pinhole_intrinsic = o3d.camera.PinholeCameraIntrinsic(
            width=d_height,
            height=d_width,
            fx=fx,
            fy=fy,
            cx=cx,
            cy=cy
        )

        frame_data = {"frame_id": frame_id,
                      'image': image,
                      'depth': depth,
                      'rgbd_image': rgbd_image,
                      'K': pinhole_intrinsic,
                      'metadata': metadata}

        frames.append(frame_data)

    return frames
