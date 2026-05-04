export const APPROVAL_STATUSES = {
  NOT_REQUIRED: "not_required",
  PENDING_APPROVAL: "pending_approval",
  APPROVED: "approved",
  REJECTED: "rejected",
};

export const USER_APPROVAL_STATUSES = Object.values(APPROVAL_STATUSES);

export const COACHING_ASSIGNMENT_REQUEST_STATUSES = {
  PENDING: "pending",
  ACCEPTED: "accepted",
  REJECTED: "rejected",
  CANCELLED: "cancelled",
};

export const COACHING_ASSIGNMENT_REQUEST_STATUS_VALUES = Object.values(
  COACHING_ASSIGNMENT_REQUEST_STATUSES
);

export const EVALUATION_REQUEST_STATUSES = {
  PENDING: "pending",
  CLAIMED: "claimed",
  REVIEWED: "reviewed",
  EXPIRED: "expired",
  CANCELLED: "cancelled",
};

export const EVALUATION_REQUEST_STATUS_VALUES = Object.values(
  EVALUATION_REQUEST_STATUSES
);

export const EVALUATION_SECTIONS = ["writing", "speaking"];

export const PAYMENT_TRANSACTION_TYPES = {
  TEST_CREDIT_PURCHASE: "test_credit_purchase",
};

export const PAYMENT_TRANSACTION_TYPE_VALUES = Object.values(
  PAYMENT_TRANSACTION_TYPES
);

export const PAYMENT_TRANSACTION_STATUSES = {
  PENDING: "pending",
  SUCCEEDED: "succeeded",
  FAILED: "failed",
  CANCELLED: "cancelled",
};

export const PAYMENT_TRANSACTION_STATUS_VALUES = Object.values(
  PAYMENT_TRANSACTION_STATUSES
);

export const PAYOUT_REQUEST_STATUSES = {
  PENDING: "pending",
  APPROVED: "approved",
  REJECTED: "rejected",
  PAID: "paid",
  CANCELLED: "cancelled",
};

export const PAYOUT_REQUEST_STATUS_VALUES = Object.values(
  PAYOUT_REQUEST_STATUSES
);
