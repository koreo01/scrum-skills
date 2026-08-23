"""
pipeline.py

ebanoide のメインパイプライン:
  1. 議事録読み込み
  2. 除外フィルタ
  3. Detector (パターン検出)
  4. Responder (応答生成)
  5. Guard (品質検証)
  6. Aggregator (日次サマリ生成)
  7. Slack DM 配信

実行例:
    python scripts/pipeline.py
    python scripts/pipeline.py --dry-run
    python scripts/pipeline.py --transcript-dir /path/to/transcripts/
    python scripts/pipeline.py --date 2026-05-15
"""

import argparse
import json
import logging
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional
from zoneinfo import ZoneInfo

import yaml
from anthropic import Anthropic

# 親ディレクトリをパスに追加
sys.path.insert(0, str(Path(__file__).parent))

from extract_transcript import extract_transcript
# from slack_notify import send_dm  # 実装時に有効化


# ─────────────────────────────────────
# 設定読み込み
# ─────────────────────────────────────

def load_config(config_path: str) -> dict:
    """YAMLファイルから設定を読み込む"""
    with open(config_path, encoding="utf-8") as f:
        return yaml.safe_load(f)


def load_prompt(prompt_path: str) -> str:
    """プロンプトファイルからSystem Prompt部分のみを抽出"""
    with open(prompt_path, encoding="utf-8") as f:
        content = f.read()

    # ```...``` で囲まれた最初のブロックをSystem Promptとして抽出
    import re
    match = re.search(r"```\n?(.*?)\n?```", content, re.DOTALL)
    if match:
        return match.group(1)
    return content


def load_fewshots(pattern_id: str, n: int = 2) -> str:
    """指定パターンのFew-shot例をn個読み込んで文字列で返す"""
    fewshot_path = Path(__file__).parent.parent / "fewshots" / f"{pattern_id}_examples.md"
    if not fewshot_path.exists():
        return ""

    with open(fewshot_path, encoding="utf-8") as f:
        content = f.read()

    # Few-shot のセクションを抽出して連結
    import re
    examples = re.findall(r"## Few-shot \d+:.*?(?=^##|\Z)", content, re.DOTALL | re.MULTILINE)
    return "\n\n".join(examples[:n])


# ─────────────────────────────────────
# ロギング設定
# ─────────────────────────────────────

def setup_logging(config: dict):
    log_file = config.get("logging", {}).get("log_file", "./logs/ebanoide.log")
    log_level = config.get("logging", {}).get("log_level", "INFO")

    Path(log_file).parent.mkdir(parents=True, exist_ok=True)

    logging.basicConfig(
        level=getattr(logging, log_level),
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        handlers=[
            logging.FileHandler(log_file, encoding="utf-8"),
            logging.StreamHandler(),
        ],
    )


# ─────────────────────────────────────
# 除外フィルタ (ルールベース予選)
# ─────────────────────────────────────

PERSONAL_KEYWORDS = [
    "体調不良", "通院", "お休み", "欠席", "早退", "申し訳ありません",
    "私用", "家庭の事情", "保育園", "幼稚園",
    "耳鳴り", "頭痛", "発熱", "お大事に", "療養",
]

BUSINESS_NOTICE_KEYWORDS = [
    "完了しました", "対応済み", "マージしました", "デプロイ",
    "確認お願い", "レビューお願い", "アサインしました",
]

GREETING_WORDS = {
    "お疲れ様です", "おはようございます", "ありがとうございます",
    "よろしくお願いします", "失礼します", "失礼しました",
}

ACKNOWLEDGMENT_WORDS = {
    "はい", "了解です", "承知しました", "了解", "承知",
    "ok", "okです", "オッケー", "なるほど", "そうですね",
}

BOT_USERS = {"USLACKBOT", "Slackbot", "GitHub", "Gemini"}


def should_exclude(utterance: dict) -> tuple[bool, str]:
    """発言を除外すべきか判定"""
    text = utterance.get("text", "")
    speaker = utterance.get("speaker", "")

    # E-6: bot発言
    if speaker in BOT_USERS:
        return (True, "E-6: bot")

    # 短すぎる発言は除外
    if len(text) < 20:
        # ただし完全一致するキーワードでなければ通す
        if text.strip() not in GREETING_WORDS and text.strip() not in ACKNOWLEDGMENT_WORDS:
            return (True, "E-too-short")
        return (True, "E-7/E-9: short_response")

    # E-1: 個人事情
    if any(kw in text for kw in PERSONAL_KEYWORDS):
        # ただし、人事情と業務話題が混ざる場合は判定保留
        if len(text) < 50:
            return (True, "E-1: personal_matter")

    # E-7: 挨拶のみ
    if text.strip() in GREETING_WORDS:
        return (True, "E-7: greeting")

    # E-9: 短い相槌
    if text.strip() in ACKNOWLEDGMENT_WORDS:
        return (True, "E-9: acknowledgment")

    return (False, "")


# ─────────────────────────────────────
# Detector: パターン検出
# ─────────────────────────────────────

def build_detector_prompt(detector_template: str, meta: dict, transcript_chunk: list[dict]) -> str:
    """Detector用のプロンプトを構築"""
    transcript_text = "\n".join([
        f"[{u['timestamp']}] {u['speaker']}: {u['text']}"
        for u in transcript_chunk
    ])

    return detector_template \
        .replace("{meeting_title}", meta.get("title", "")) \
        .replace("{meeting_datetime}", meta.get("date", "")) \
        .replace("{participants}", ", ".join(meta.get("participants", []))) \
        .replace("{transcript_text}", transcript_text)


def chunk_utterances(utterances: list[dict], max_chars: int = 12000) -> list[list[dict]]:
    """発言リストをLLMに渡せるサイズに分割"""
    chunks = []
    current = []
    current_size = 0

    for u in utterances:
        u_size = len(u.get("text", ""))
        if current_size + u_size > max_chars and current:
            chunks.append(current)
            current = []
            current_size = 0
        current.append(u)
        current_size += u_size

    if current:
        chunks.append(current)

    return chunks


def run_detector(client: Anthropic, config: dict, meta: dict, utterances: list[dict]) -> list[dict]:
    """Detector を実行してパターン検出結果を返す"""
    logger = logging.getLogger("detector")
    detector_template = load_prompt(
        Path(__file__).parent.parent / "prompts" / "01_detector.md"
    )

    model = config["ai_models"]["detector"]["model"]
    max_tokens = config["ai_models"]["detector"]["max_tokens"]

    all_detections = []

    for chunk in chunk_utterances(utterances):
        prompt = build_detector_prompt(detector_template, meta, chunk)

        try:
            response = client.messages.create(
                model=model,
                max_tokens=max_tokens,
                messages=[{"role": "user", "content": prompt}],
            )

            content = response.content[0].text

            # JSON 部分を抽出
            import re
            json_match = re.search(r"\{.*\}", content, re.DOTALL)
            if json_match:
                result = json.loads(json_match.group())
                patterns = result.get("patterns", [])
                all_detections.extend(patterns)
                logger.info(f"検出: {len(patterns)}件 (chunk={len(chunk)} utterances)")
        except Exception as e:
            logger.error(f"Detector 実行エラー: {e}")
            continue

    return all_detections


# ─────────────────────────────────────
# Responder: 応答生成
# ─────────────────────────────────────

def run_responder(client: Anthropic, config: dict, detection: dict, meeting_meta: dict) -> Optional[dict]:
    """単一の検出に対して2層出力を生成"""
    logger = logging.getLogger("responder")

    responder_template = load_prompt(
        Path(__file__).parent.parent / "prompts" / "02_responder.md"
    )
    fewshots = load_fewshots(detection["id"], n=2)

    model = config["ai_models"]["responder"]["model"]
    max_tokens = config["ai_models"]["responder"]["max_tokens"]

    # プロンプトテンプレートの変数置換
    prompt = responder_template
    prompt = prompt.replace("{pattern_id}", detection.get("id", ""))
    prompt = prompt.replace("{pattern_name}", detection.get("id", ""))  # 別途名前マッピングが必要
    prompt = prompt.replace("{confidence}", detection.get("confidence", ""))
    prompt = prompt.replace("{speaker}", detection.get("speaker", ""))
    prompt = prompt.replace("{timestamp}", detection.get("timestamp", ""))
    prompt = prompt.replace("{trigger_text}", detection.get("trigger_text", ""))
    prompt = prompt.replace("{context_summary}", detection.get("context_summary", ""))
    prompt = prompt.replace("{meeting_title}", meeting_meta.get("title", ""))
    prompt = prompt.replace("{reasoning}", detection.get("reasoning", ""))

    full_prompt = f"{prompt}\n\n## Few-shot 例\n\n{fewshots}"

    try:
        response = client.messages.create(
            model=model,
            max_tokens=max_tokens,
            messages=[{"role": "user", "content": full_prompt}],
        )

        content = response.content[0].text

        import re
        json_match = re.search(r"\{.*\}", content, re.DOTALL)
        if json_match:
            return json.loads(json_match.group())
    except Exception as e:
        logger.error(f"Responder 実行エラー: {e}")

    return None


# ─────────────────────────────────────
# Guard: 品質検証
# ─────────────────────────────────────

def run_guard(client: Anthropic, config: dict, response: dict) -> dict:
    """応答の品質を検証"""
    logger = logging.getLogger("guard")

    guard_template = load_prompt(
        Path(__file__).parent.parent / "prompts" / "03_guard.md"
    )

    model = config["ai_models"]["guard"]["model"]
    max_tokens = config["ai_models"]["guard"]["max_tokens"]

    prompt = guard_template.replace(
        "{generated_response}",
        json.dumps(response, ensure_ascii=False, indent=2)
    )

    try:
        api_response = client.messages.create(
            model=model,
            max_tokens=max_tokens,
            messages=[{"role": "user", "content": prompt}],
        )

        content = api_response.content[0].text

        import re
        json_match = re.search(r"\{.*\}", content, re.DOTALL)
        if json_match:
            return json.loads(json_match.group())
    except Exception as e:
        logger.error(f"Guard 実行エラー: {e}")

    return {"pass": False, "violations": ["guard_error"], "score": 0}


# ─────────────────────────────────────
# Aggregator: 日次サマリ生成
# ─────────────────────────────────────

def run_aggregator(client: Anthropic, config: dict,
                   responses: list[dict], date: str) -> str:
    """日次サマリを生成"""
    logger = logging.getLogger("aggregator")

    aggregator_template = load_prompt(
        Path(__file__).parent.parent / "prompts" / "04_aggregator.md"
    )

    model = config["ai_models"]["aggregator"]["model"]
    max_tokens = config["ai_models"]["aggregator"]["max_tokens"]

    # 傾向データ構築（実装時に詳細化）
    trend_data = build_trend_data(config, date)

    prompt = aggregator_template
    prompt = prompt.replace("{date}", date)
    prompt = prompt.replace("{detections}", json.dumps(responses, ensure_ascii=False))
    prompt = prompt.replace("{trend_data}", json.dumps(trend_data, ensure_ascii=False))
    prompt = prompt.replace("{max_items_per_day}", str(config["notification"]["max_items_per_day"]))

    try:
        response = client.messages.create(
            model=model,
            max_tokens=max_tokens,
            messages=[{"role": "user", "content": prompt}],
        )
        return response.content[0].text
    except Exception as e:
        logger.error(f"Aggregator 実行エラー: {e}")
        return f"エラー: 日次サマリ生成に失敗しました ({e})"


def build_trend_data(config: dict, date: str) -> dict:
    """過去N日の傾向データを構築"""
    trend_window = config.get("meta_analysis", {}).get("trend_window_days", 7)
    history_path = Path(config.get("logging", {}).get("analysis_history_path", "./data/analysis_history/"))

    if not history_path.exists():
        return {"note": "傾向データなし（初回実行）"}

    # 過去N日のJSONを集計（実装時に詳細化）
    return {
        "trend_window_days": trend_window,
        "pattern_counts_total": {},
        "note": "傾向データ集計実装中",
    }


# ─────────────────────────────────────
# メインパイプライン
# ─────────────────────────────────────

def process_transcript(client: Anthropic, config: dict,
                       transcript_path: Path, dry_run: bool = False) -> list[dict]:
    """1つの議事録を処理して、Responder 出力のリストを返す"""
    logger = logging.getLogger("pipeline")
    logger.info(f"処理開始: {transcript_path}")

    # 議事録抽出
    transcript = extract_transcript(str(transcript_path))
    utterances = transcript["utterances"]
    meta = transcript["meta"]

    # 除外フィルタ
    filtered = []
    excluded_count = 0
    for u in utterances:
        excluded, reason = should_exclude(u)
        if excluded:
            excluded_count += 1
            continue
        filtered.append(u)

    logger.info(f"  発言: {len(utterances)}件、除外: {excluded_count}件、対象: {len(filtered)}件")

    # Detector
    detections = run_detector(client, config, meta, filtered)
    logger.info(f"  検出: {len(detections)}件")

    # 上限を適用
    max_per_meeting = config.get("safety", {}).get("max_detections_per_meeting", 5)
    if len(detections) > max_per_meeting:
        # Tier の高い順にソートしてから上限適用
        tier_order = {"S": 0, "A": 1, "B": 2, "C": 3}
        # 注: id から tier を引くマッピングは config 経由で取得する想定
        detections = detections[:max_per_meeting]

    # Responder + Guard
    responses = []
    for detection in detections:
        response = run_responder(client, config, detection, meta)
        if response is None:
            continue

        # 健全例(指摘対象外)はスキップ
        if response.get("_judgment") == "HEALTHY_EXAMPLE":
            logger.info(f"  健全例としてスキップ: {detection.get('speaker')}")
            continue

        validation = run_guard(client, config, response)
        if not validation.get("pass"):
            logger.warning(f"  Guard NG: {validation.get('violations')}")
            # 再生成は実装時に追加
            continue

        # 議事録のメタデータを追加
        response["_meeting"] = {
            "title": meta.get("title"),
            "date": meta.get("date"),
            "source": str(transcript_path.name),
        }
        responses.append(response)

    logger.info(f"  最終応答: {len(responses)}件")
    return responses


def main():
    parser = argparse.ArgumentParser(description="ebanoide パイプライン")
    parser.add_argument("--config", default="config/config.yaml", help="設定ファイルパス")
    parser.add_argument("--dry-run", action="store_true", help="Slack送信せずログのみ")
    parser.add_argument("--transcript-dir", help="議事録ディレクトリ（config上書き）")
    parser.add_argument("--date", help="処理対象日 (YYYY-MM-DD)")
    parser.add_argument("--transcript", help="単一議事録ファイルを処理")

    args = parser.parse_args()

    # 設定読み込み
    config = load_config(args.config)
    if args.dry_run:
        config["safety"]["dry_run"] = True

    setup_logging(config)
    logger = logging.getLogger("main")

    # API クライアント初期化
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        logger.error("ANTHROPIC_API_KEY 環境変数が設定されていません")
        sys.exit(1)
    client = Anthropic(api_key=api_key)

    # 処理対象日
    target_date = args.date or datetime.now(ZoneInfo(config["delivery"]["timezone"])).strftime("%Y-%m-%d")
    logger.info(f"対象日: {target_date}")

    # 議事録収集
    all_responses = []

    if args.transcript:
        # 単一ファイル
        responses = process_transcript(client, config, Path(args.transcript), args.dry_run)
        all_responses.extend(responses)
    else:
        # ディレクトリから収集
        transcript_dir = Path(args.transcript_dir or config["transcript_source"]["local"]["path"])
        for path in sorted(transcript_dir.glob("*.docx")):
            # 対象会議のキーワードチェック
            target_keywords = config["target_meetings"]["include_keywords"]
            exclude_keywords = config["target_meetings"]["exclude_keywords"]

            if not any(kw in path.name for kw in target_keywords):
                logger.info(f"スキップ(対象外): {path.name}")
                continue
            if any(kw in path.name for kw in exclude_keywords):
                logger.info(f"スキップ(除外): {path.name}")
                continue

            responses = process_transcript(client, config, path, args.dry_run)
            all_responses.extend(responses)

    # 日次サマリ生成
    if all_responses:
        summary = run_aggregator(client, config, all_responses, target_date)
    else:
        summary = f"🔍 ebanoide 日次分析【{target_date}】\n\n本日はebanoide検出パターンに該当する発言は見つかりませんでした。"

    # 履歴保存
    history_dir = Path(config["logging"]["analysis_history_path"])
    history_dir.mkdir(parents=True, exist_ok=True)
    with open(history_dir / f"{target_date}.json", "w", encoding="utf-8") as f:
        json.dump({
            "date": target_date,
            "responses": all_responses,
            "summary_text": summary,
        }, f, ensure_ascii=False, indent=2)

    # Slack 配信
    if args.dry_run or config["safety"]["dry_run"]:
        logger.info("=== DRY RUN: 以下を送信予定 ===")
        print(summary)
    else:
        # send_dm(config, summary)  # 実装時に有効化
        logger.info("Slack配信は未実装。実装後に有効化してください")
        print(summary)

    logger.info("パイプライン完了")


if __name__ == "__main__":
    main()
