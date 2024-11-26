import numpy as np


def to_homogeneous(points: np.array) -> np.array:
    """
    Convert points to homogeneous coordinates.
    points: Nx2 or Nx3 array of points.
    return: Nx3 or Nx4 array of points in homogeneous coordinates.
    """
    return np.concatenate([points, np.ones((points.shape[0], 1))], axis=1)

def from_homogeneous(points: np.array) -> np.array:
    """
    Convert points from homogeneous coordinates.
    points: Nx3 or Nx4 array of points in homogeneous coordinates.
    return: Nx2 or Nx3 array of points.
    """
    return points[:, :-1] / points[:, -1:]


def backproject_points(img_points: np.array, depth: np.array, inv_K: np.array) -> np.array:
    """
    Backproject points using the camera matrix.
    img_points: Nx2 or Nx3 array of points in image coordinates.
    inv_K: 3x3 inverse camera matrix.
    return: Nx3 array of backprojected points.
    """
    assert img_points.shape[0] == depth.shape[0], f"Number of points {img_points.shape[0]} and depth {depth.shape[0]} must match."
    if img_points.shape[1] == 2:
        img_points = to_homogeneous(img_points)
    if depth.ndim == 1:
        depth = depth[:, None]
    return (inv_K @ img_points.T).T * depth


def project_points(global_points: np.array, K: np.array) -> np.array:
    """
    Project points using the camera matrix.
    global_points: Nx3 or Nx4 array of points in global coordinates.
    K: 3x3 camera matrix.
    return: Nx3 array of projected points.
    """
    if global_points.shape[1] == 4:
        global_points = from_homogeneous(global_points)
    return (K @ global_points.T).T


def get_depth_for_points_from_depth_map(img_points: np.array, depth_map: np.array) -> np.array:
    """
    img_points: Nx2 or Nx3 array of points in image coordinates.
    depth_map: HxW array of depth values.
    Note: Double check that the depth_map was resized to the image size.
    """
    img_points = img_points.astype(int)
    depth_values = depth_map[img_points[:, 1], img_points[:, 0]]
    return depth_values



    