import dotenv from "dotenv";

dotenv.config();

const env = {
  nodeEnv: process.env.NODE_ENV || "development",
  port: Number(process.env.PORT || 8080),
  dbUrl: process.env.DB_URL || "mongodb://127.0.0.1:27017",
  dbName: process.env.DB_NAME || "ielts_mock_platform",
  jwtAccessSecret: process.env.JWT_ACCESS_SECRET || "change-me-access-secret",
  jwtRefreshSecret:
    process.env.JWT_REFRESH_SECRET || "change-me-refresh-secret",
  accessTokenTtl: process.env.JWT_ACCESS_TTL || "15m",
  refreshTokenTtlDays: Number(process.env.JWT_REFRESH_TTL_DAYS || 7),
  clientOrigin: process.env.CLIENT_ORIGIN || "*",
  jsonBodyLimit: process.env.JSON_BODY_LIMIT || "1mb",
  urlEncodedBodyLimit: process.env.URLENCODED_BODY_LIMIT || "1mb",
  mediaStorageProvider: process.env.MEDIA_STORAGE_PROVIDER || "local",
  mediaUploadDir: process.env.MEDIA_UPLOAD_DIR || "uploads",
  mediaPublicBasePath: process.env.MEDIA_PUBLIC_BASE_PATH || "/media",
  mediaMaxImageBytes: Number(process.env.MEDIA_MAX_IMAGE_BYTES || 5 * 1024 * 1024),
  mediaMaxAudioBytes: Number(process.env.MEDIA_MAX_AUDIO_BYTES || 20 * 1024 * 1024),
  mediaMaxFilesPerRequest: Number(process.env.MEDIA_MAX_FILES_PER_REQUEST || 10),
  platformAdminSeedEmail:
    process.env.PLATFORM_ADMIN_SEED_EMAIL || "admin@g.com",
  platformAdminSeedPassword:
    process.env.PLATFORM_ADMIN_SEED_PASSWORD || "Admin@12345",
};

export default env;
