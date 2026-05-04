import fs from "fs/promises";
import path from "path";
import { randomUUID } from "crypto";
import env from "../../../config/env.js";

function toPosixPath(filePath) {
  return filePath.split(path.sep).join("/");
}

function sanitizePathSegment(segment) {
  return String(segment || "")
    .trim()
    .replace(/[^a-zA-Z0-9._-]/g, "-")
    .replace(/-{2,}/g, "-")
    .replace(/^[-.]+|[-.]+$/g, "")
    .slice(0, 80);
}

function normalizeTargetFolder(targetFolder) {
  const cleaned = String(targetFolder || "general")
    .replace(/\\/g, "/")
    .split("/")
    .map(sanitizePathSegment)
    .filter(Boolean)
    .join("/");
  return cleaned || "general";
}

function buildPublicUrl(storagePath) {
  const base = String(env.mediaPublicBasePath || "/media").replace(/\/+$/, "");
  return `${base}/${toPosixPath(storagePath).replace(/^\/+/, "")}`;
}

function resolveRootDirectory() {
  const configured = String(env.mediaUploadDir || "uploads").trim() || "uploads";
  return path.isAbsolute(configured)
    ? configured
    : path.resolve(process.cwd(), configured);
}

function getFileExtension(originalName = "") {
  const ext = path.extname(originalName).trim().toLowerCase();
  if (!ext) {
    return "";
  }
  return ext.slice(0, 12);
}

class LocalDiskMediaStorageService {
  constructor() {
    this.rootDir = resolveRootDirectory();
  }

  async ensureReady() {
    await fs.mkdir(this.rootDir, { recursive: true });
  }

  async saveUploadedFile({ file, targetFolder }) {
    if (!file || !file.buffer) {
      throw new Error("Uploaded file is required");
    }

    const folder = normalizeTargetFolder(targetFolder);
    const subdir = path.join(this.rootDir, folder);
    await fs.mkdir(subdir, { recursive: true });

    const extension = getFileExtension(file.originalname);
    const mediaId = randomUUID();
    const storedFileName = `${Date.now()}-${mediaId}${extension}`;
    const absolutePath = path.join(subdir, storedFileName);

    await fs.writeFile(absolutePath, file.buffer);

    const storagePath = toPosixPath(path.join(folder, storedFileName));
    return {
      mediaId,
      fileName: file.originalname || storedFileName,
      mimeType: file.mimetype || "application/octet-stream",
      sizeBytes: Number(file.size || file.buffer.length || 0),
      storagePath,
      publicUrl: buildPublicUrl(storagePath),
      uploadedAt: new Date(),
    };
  }

  async deleteByStoragePath(storagePath) {
    if (!storagePath || typeof storagePath !== "string") {
      return;
    }

    const normalized = storagePath
      .replace(/\\/g, "/")
      .split("/")
      .map(sanitizePathSegment)
      .filter(Boolean)
      .join("/");

    if (!normalized) {
      return;
    }

    const absolutePath = path.join(this.rootDir, normalized);
    try {
      await fs.unlink(absolutePath);
    } catch (e) {
      if (e && e.code === "ENOENT") {
        return;
      }
      throw e;
    }
  }
}

export const mediaStorageService = new LocalDiskMediaStorageService();

export function getMediaStorageRootDir() {
	return mediaStorageService.rootDir;
}

export async function ensureMediaStorageReady() {
	await mediaStorageService.ensureReady();
}
