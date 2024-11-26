import numpy as np

from scipy.optimize import minimize
from scipy.spatial.transform import Rotation as R

from .points_transforms import to_homogeneous, from_homogeneous

def rotation_matrix_from_vector(rot_vec):
    """
    Convert a 3D rotation vector to a 3x3 rotation matrix.
    """
    return R.from_rotvec(rot_vec).as_matrix()


def get_extrinsic_matrix_from_vectors(rot_vec, t_vec):
    """
    Get the extrinsic matrix from rotation and translation vectors.
    """
    R_matrix = rotation_matrix_from_vector(rot_vec)
    extrinsic_matrix = np.eye(4)
    extrinsic_matrix[:3, :3] = R_matrix
    extrinsic_matrix[:3, 3] = t_vec
    return extrinsic_matrix

def _objective_function(params, source_points, target_points):
    """
    Objective function to minimize alignment error.
    
    Args:
        params: Concatenated rotation vector (3D) and translation vector (3D).
        source_points: Nx4 array of source points.
        target_points: Nx4 array of target points.
        
    Returns:
        Total alignment error.
    """
    # Extract rotation and translation
    rot_vec = params[:3]
    t = params[3:]
    extrinsic_matrix = get_extrinsic_matrix_from_vectors(rot_vec, t)

    # Apply transformation
    transformed_points = (extrinsic_matrix @ source_points.T).T

    # Compute error
    error = ((target_points - transformed_points)[:, :3]**2).sum(axis=1)
    return error.mean()

def solve_extrinsic_optimization(source_points, target_points):
    """
    Solve for the best extrinsic matrix (R, t) using optimization.
    """
    # Initialize parameters (zero rotation, zero translation)
    initial_params = np.zeros(6)  # 3 for rotation, 3 for translation
    if source_points.shape[1] == 3:
        source_points = to_homogeneous(source_points)
    if target_points.shape[1] == 3:
        target_points = to_homogeneous(target_points)

    # Optimize
    result = minimize(
        _objective_function,
        initial_params,
        args=(source_points, target_points),
        method="L-BFGS-B"
    )

    # Extract optimized rotation and translation
    extrinsic_matrix = get_extrinsic_matrix_from_vectors(result.x[:3], result.x[3:])

    return extrinsic_matrix, result.fun  # Return matrix and final error
