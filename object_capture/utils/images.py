import os
import typing as tp
import matplotlib.pyplot as plt
import json
import numpy as np
import cv2

from PIL import Image


def get_image_from_frame_id(data_folder: str, frame_id: str) -> Image.Image:
    color_image_path = os.path.join(data_folder, f"frame_{frame_id}_colorImage.jpg")
    image = Image.open(color_image_path)
    image = image.transpose(Image.ROTATE_270)
    return image


def get_metadata_from_frame_id(data_folder: str, frame_id: str) -> tp.Dict[str, tp.Any]:
    metadata_path = os.path.join(data_folder, f"frame_{frame_id}_metadata.json")
    metadata = json.load(open(metadata_path))
    return metadata


def get_depth_image_from_frame_id(data_folder: str, 
                                  frame_id: str, 
                                  metadata: tp.Dict) -> np.array:
    depth_image_path = os.path.join(data_folder, f"frame_{frame_id}_depthImage.png")
    depth_image = Image.open(depth_image_path)
    depth_image = depth_image.transpose(Image.ROTATE_270)
    depth_image = np.array(depth_image).astype(np.float32)

    min_depth = metadata['minDepth']
    max_depth = metadata['maxDepth']
    depth_scale = 255 / (max_depth - min_depth)
    depth_image  = (depth_image / depth_scale) + min_depth
    return depth_image


def get_K_from_metadata(metadata: tp.Dict[str, tp.Any], W: int, H: int) -> np.array:
    
    K = np.array(metadata['cameraIntrinsics']).T
    # swap x and y
    fy, fx = K[0, 0], K[1, 1]
    cy, cx = K[0, 2], K[1, 2]
    K[0, 0], K[1, 1] = fx, fy
    K[0, 2], K[1, 2] = cx, cy

    K[0, :] *= W / metadata['cameraReferenceDimensions']['height']
    K[1, :] *= H / metadata['cameraReferenceDimensions']['width']
    return K

def get_images(data_folder: str) -> tp.List[Image.Image]:
    # Find all unique frame IDs by scanning filenames
    frame_ids = set()
    for file_name in os.listdir(data_folder):
        if file_name.startswith("frame_"):
            frame_id = file_name.split('_')[1]
            frame_ids.add(frame_id)
    images = []
    for frame_id in sorted(frame_ids, key=int):        
        image = get_image_from_frame_id(data_folder, frame_id)
        W, H = image.size
        metadata = get_metadata_from_frame_id(data_folder, frame_id)
        K = get_K_from_metadata(metadata, W, H)
        inv_K = np.linalg.inv(K)
        depth = get_depth_image_from_frame_id(data_folder, frame_id, metadata)
        depth = cv2.resize(depth, (W, H), interpolation=cv2.INTER_NEAREST)

        setattr(image, 'K', K)
        setattr(image, 'inv_K', inv_K)
        setattr(image, 'depth', depth)
        images.append(image)
        
    return images


def plot_images(images: tp.List[Image.Image]) -> None:
    fig, axes = plt.subplots(1, len(images), figsize=(20, 10), squeeze=False)
    for ax, image in zip(axes.flat,
                         images):
        ax.imshow(image)
        ax.axis("off")
    plt.show()
