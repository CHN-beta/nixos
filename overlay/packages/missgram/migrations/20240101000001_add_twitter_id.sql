-- 1. 去除早期因重试导致的历史重复数据，仅保留最新（或最老）的一条
DELETE FROM "Record"
WHERE ctid NOT IN (
    SELECT min(ctid)
    FROM "Record"
    GROUP BY misskey_note
);

-- 2. 为 misskey_note 添加唯一索引，这是后续 ON CONFLICT 语法必须的前提
CREATE UNIQUE INDEX IF NOT EXISTS record_misskey_note_idx ON "Record" (misskey_note);

-- 3. 添加保存推文 ID 的列
ALTER TABLE "Record" ADD COLUMN IF NOT EXISTS twitter_tweet_id TEXT;

-- 4. 允许没有发往 Telegram 时（即电报 ID 为空）也能成功写入（防空报错）
ALTER TABLE "Record" ALTER COLUMN telegram_message_id DROP NOT NULL;