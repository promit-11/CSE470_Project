import mongoose from "mongoose";
import { USER_ROLES } from "../../../constants/roles.js";
import { ROLES } from "../../../constants/roles.js";
import { APPROVAL_STATUSES, USER_APPROVAL_STATUSES } from "../../../constants/workflow-statuses.js";

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 80 },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    passwordHash: { type: String, required: true },
    role: { type: String, enum: USER_ROLES, required: true },
    status: { type: String, enum: ["active", "inactive", "blocked"], default: "active" },
    approvalStatus: {
      type: String,
      enum: USER_APPROVAL_STATUSES,
      default: function defaultApprovalStatus() {
        const role = this?.role;
        return role === ROLES.TEACHER
          ? APPROVAL_STATUSES.PENDING_APPROVAL
          : APPROVAL_STATUSES.NOT_REQUIRED;
      },
    },
  },
  { timestamps: true }
);

userSchema.path("approvalStatus").validate(function validateApprovalStatus(value) {
  if (this.role === ROLES.TEACHER) {
    return [
      APPROVAL_STATUSES.PENDING_APPROVAL,
      APPROVAL_STATUSES.APPROVED,
      APPROVAL_STATUSES.REJECTED,
    ].includes(value);
  }
  return value === APPROVAL_STATUSES.NOT_REQUIRED;
}, "Invalid approvalStatus for role");

userSchema.index({ role: 1, approvalStatus: 1 });

const User = mongoose.model("V1User", userSchema);

export default User;
