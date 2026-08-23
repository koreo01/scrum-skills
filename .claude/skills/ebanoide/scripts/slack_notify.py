"""
slack_notify.py

日次サマリを Slack DM で SM に配信する。

使用例:
    from slack_notify import send_dm
    send_dm(config, summary_text)

事前準備:
    1. Slack App を作成 (https://api.slack.com/apps)
    2. OAuth Scopes に chat:write, im:write を追加
    3. ワークスペースにインストール
    4. Bot User OAuth Token を取得
    5. 環境変数 SLACK_BOT_TOKEN にセット
    6. config の notification.recipient_user_id にあなたのSlack User IDをセット
"""

import logging
import os
import sys
from typing import Optional

# pip install slack_sdk
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError


logger = logging.getLogger("slack_notify")


def send_dm(config: dict, summary_text: str) -> bool:
    """
    SM に Slack DM で日次サマリを送信する。

    Args:
        config: 設定辞書 (config.yamlから読み込んだもの)
        summary_text: 配信するサマリテキスト (Slack mrkdwn形式)

    Returns:
        bool: 送信成功なら True
    """
    token = os.environ.get("SLACK_BOT_TOKEN")
    if not token:
        logger.error("SLACK_BOT_TOKEN 環境変数が設定されていません")
        return False

    recipient_user_id = config["notification"]["recipient_user_id"]
    if not recipient_user_id or recipient_user_id == "U_XXXXXXXX":
        logger.error("config.notification.recipient_user_id が未設定です")
        return False

    client = WebClient(token=token)

    try:
        # DM チャンネルを開く
        dm_open = client.conversations_open(users=recipient_user_id)
        channel_id = dm_open["channel"]["id"]

        # 長文の場合は分割送信（Slack の3000字制限対策）
        chunks = split_long_message(summary_text)

        for i, chunk in enumerate(chunks):
            response = client.chat_postMessage(
                channel=channel_id,
                text=chunk,
                blocks=build_blocks(chunk),
                mrkdwn=True,
            )

            if not response.get("ok"):
                logger.error(f"chunk {i+1}/{len(chunks)} 送信失敗: {response}")
                return False

        logger.info(f"Slack DM 送信完了: {len(chunks)} chunks, user={recipient_user_id}")
        return True

    except SlackApiError as e:
        logger.error(f"Slack API エラー: {e.response['error']}")
        return False
    except Exception as e:
        logger.error(f"予期しないエラー: {e}")
        return False


def split_long_message(text: str, max_length: int = 2900) -> list[str]:
    """
    長文を Slack の制限内に分割する。
    セパレータ「═══」「───」で区切られた境界で分割。
    """
    if len(text) <= max_length:
        return [text]

    chunks = []
    current = ""

    for line in text.split("\n"):
        if len(current) + len(line) + 1 > max_length:
            # セクション境界（═══や───）で改ページするのが理想
            if current:
                chunks.append(current.rstrip())
            current = line + "\n"
        else:
            current += line + "\n"

    if current:
        chunks.append(current.rstrip())

    return chunks


def build_blocks(text: str) -> list[dict]:
    """Slack Block Kit 用のブロックを構築"""
    return [
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": text
            }
        }
    ]


def send_error_notification(config: dict, error_message: str) -> bool:
    """パイプライン実行中のエラーを SM に通知"""
    text = (
        "⚠️ *ebanoide エラー通知*\n\n"
        f"```\n{error_message}\n```\n\n"
        "ログを確認してください。"
    )
    return send_dm(config, text)


# ─────────────────────────────────────
# スタンドアロン実行用 (テスト)
# ─────────────────────────────────────

def main():
    """テスト送信"""
    import argparse
    import yaml

    parser = argparse.ArgumentParser(description="Slack DM テスト送信")
    parser.add_argument("--config", default="config/config.yaml")
    parser.add_argument("--message", default="🔍 ebanoide テスト送信\n\nこれはテストメッセージです。")
    args = parser.parse_args()

    with open(args.config, encoding="utf-8") as f:
        config = yaml.safe_load(f)

    logging.basicConfig(level=logging.INFO)

    success = send_dm(config, args.message)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
