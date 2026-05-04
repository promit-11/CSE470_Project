export function success(data, meta = undefined) {
  return {
    success: true,
    data,
    ...(meta ? { meta } : {}),
  };
}

export function failure(message, details = undefined) {
  return {
    success: false,
    message,
    ...(details ? { details } : {}),
  };
}
