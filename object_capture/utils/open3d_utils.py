import typing as tp
import open3d as o3d
import numpy as np
import matplotlib.pyplot as plt

from copy import deepcopy
from PIL import Image
from open3d.web_visualizer import draw


def get_pinhole_camera_intrinsic(K: np.array, width: int, height: int) -> o3d.camera.PinholeCameraIntrinsic:
     """
     K: 3x3 camera matrix in the form [[fx, 0, cx], [0, fy, cy], [0, 0, 1]].
     width: Image width.
     height: Image height.

     """
     return o3d.camera.PinholeCameraIntrinsic(
            width=width, height=height,
            fx=K[0, 0], fy=K[1, 1],
            cx=K[0, 2], cy=K[1, 2]
        )


def get_rgbd_image(img: tp.Union[Image.Image, np.array], 
                   depth: np.array, 
                   depth_trunc: float = 3.0) -> o3d.geometry.RGBDImage:
    """
    img: PIL Image or numpy array of color image.
    depth: Depth image as numpy array.
    depth_trunc: Truncation value for depth values.
    """
    color = np.array(img)
    assert color.shape[:2] == depth.shape[:2], f"Color shape {color.shape} and depth shape {depth.shape} must match."

    rgbd_image = o3d.geometry.RGBDImage.create_from_color_and_depth(
        o3d.geometry.Image(color), o3d.geometry.Image(depth), 
        depth_scale=1.0, depth_trunc=depth_trunc, 
        convert_rgb_to_intensity=False
    )
    return rgbd_image

def get_pcd_from_rgbd_image(rgbd_image: o3d.geometry.RGBDImage, 
                            intrinsic: o3d.camera.PinholeCameraIntrinsic) -> o3d.geometry.PointCloud:
    """
    rgbd_image: RGBD image.
    intrinsic: Pinhole camera intrinsic.
    """
    pcd = o3d.geometry.PointCloud.create_from_rgbd_image(
        rgbd_image, intrinsic
    )
    return pcd


def get_pcd_from_numpy(img: tp.Union[Image.Image, np.array],
                       depth: np.array,
                       K: np.array, 
                       depth_trunc: float = 3.0) -> o3d.geometry.PointCloud:
     """
     img: PIL Image or numpy array of color image.
     depth: Depth image as numpy array.
     K: 3x3 camera matrix.
     """
     rgbd_image = get_rgbd_image(img, depth, depth_trunc)
     h, w = depth.shape[:2]
     intrinsic = get_pinhole_camera_intrinsic(K, width=w, height=h)

     pcd = get_pcd_from_rgbd_image(rgbd_image, intrinsic)
     return pcd


def plot_rgbd_image(rgbd_image: o3d.geometry.RGBDImage,
                    figsize: tp.Tuple[int, int] = (10, 5)) -> None:
    plt.figure(figsize=figsize)
    plt.subplot(1, 2, 1)
    plt.title('Color image')
    color = np.array(rgbd_image.color)
    depth = np.array(rgbd_image.depth)
    plt.imshow(color)
    plt.subplot(1, 2, 2)
    plt.title('Depth image')
    plt.imshow(depth)
    # add colorbar
    plt.colorbar()
    plt.show()

def draw_pcd(pcd: tp.Union[tp.List[o3d.geometry.PointCloud], o3d.geometry.PointCloud],
             viz_transform: tp.Sequence = [[1, 0, 0, 0], [0, -1, 0, 0], [0, 0, -1, 0], [0, 0, 0, 1]]) -> None:
    pcd = [pcd] if isinstance(pcd, o3d.geometry.PointCloud) else pcd
    pcd = deepcopy(pcd)
    for _pcd in pcd:
        _pcd.transform(viz_transform)
    draw(pcd)


def draw_registration_result_pcd(src_pcd: o3d.geometry.PointCloud, 
                                 tgt_pcd: o3d.geometry.PointCloud,
                                 src_transform: np.array) -> None:
    src_pcd = deepcopy(src_pcd)
    src_pcd.transform(src_transform)
    draw_pcd([src_pcd, tgt_pcd])

