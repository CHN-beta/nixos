import path from 'path'
import fs from 'fs/promises'
import { v4 as uuidv4 } from 'uuid'

export const UPLOAD_DIR = path.join(process.cwd(), 'uploads')
export const MAX_FILE_SIZE = 10 * 1024 * 1024 // 10MB

export async function ensureUploadDir() {
  await fs.mkdir(UPLOAD_DIR, { recursive: true })
}

export async function saveFile(file: File): Promise<string> {
  await ensureUploadDir()
  const ext = path.extname(file.name)
  const base = path.basename(file.name, ext).replace(/[^a-zA-Z0-9_-]/g, '_')
  const filename = `${uuidv4()}-${base}${ext}`
  const filepath = path.join(UPLOAD_DIR, filename)
  const buffer = Buffer.from(await file.arrayBuffer())
  await fs.writeFile(filepath, buffer)
  return `/api/uploads/${filename}`
}
