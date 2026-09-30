#!/usr/bin/env python3
"""
USM (User Story Mapping) を Miro ボードに自動展開するスクリプト。

Optional Integration: Miroは企業/Projectが承認し、利用者が
MIRO_ACCESS_TOKEN・MIRO_BOARD_IDを明示的に設定した場合のみ使用する
（README.md「External Tools / Services Policy」参照）。承認・設定が
ない場合はこのスクリプトを実行しない。

使い方:
  python deploy_usm.py usm_data.json

JSONフォーマット:
  - stories は文字列（ラベルのみ、status=new扱い）またはオブジェクト {"label": "...", "status": "done|created|new"}
  - release_lines の after_story_index はストーリーの行番号（0始まり）
"""

import json
import os
import sys
import time
import requests
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(Path(__file__).parent.parent / ".env")

MIRO_TOKEN = os.environ["MIRO_ACCESS_TOKEN"]
BOARD_ID = os.environ["MIRO_BOARD_ID"]
BASE_URL = f"https://api.miro.com/v2/boards/{BOARD_ID}"
HEADERS = {
    "Authorization": f"Bearer {MIRO_TOKEN}",
    "Content-Type": "application/json",
}

# --- レイアウト定数 ---
STICKY_W = 300
STICKY_H = 152
COL_GAP = 60
ROW_GAP = 50
BAND_LABEL_H = 40
SECTION_PAD = 30
BB_SEPARATOR = 100
RELEASE_COL_W = 180   # 左端のRelease列の幅

# Story色（状態別、同系統で区別）
STORY_COLORS = {
    "done": "gray",           # 完了 — グレー
    "created": "light_yellow", # 起票済み — 薄い黄色
    "new": "yellow",           # 未対応 — 黄色（目立つ）
}

COLORS = {
    "backbone": "light_pink",
    "narrative": "light_green",
}

BAND_COLORS = {
    "backbone": "#c6dcff",
    "narrative": "#f8d3af",
    "story": "#adf0c7",
}


def api_post(endpoint, payload):
    url = f"{BASE_URL}/{endpoint}"
    resp = requests.post(url, headers=HEADERS, json=payload)
    if resp.status_code == 429:
        retry_after = int(resp.headers.get("Retry-After", 2))
        print(f"  Rate limited, waiting {retry_after}s...")
        time.sleep(retry_after)
        resp = requests.post(url, headers=HEADERS, json=payload)
    if not resp.ok:
        import json as _json
        print(f"  API ERROR {resp.status_code} on {endpoint}")
        print(f"  payload: {_json.dumps(payload, ensure_ascii=False)[:800]}")
        print(f"  response: {resp.text[:400]}")
    resp.raise_for_status()
    return resp.json()


def create_frame(title, x, y, width, height):
    payload = {
        "data": {"title": title, "format": "custom", "type": "freeform"},
        "style": {"fillColor": "#ffffff"},
        "position": {"x": x, "y": y, "origin": "center"},
        "geometry": {"width": width, "height": height},
    }
    result = api_post("frames", payload)
    print(f"  Frame: {title} (id={result['id']})")
    return result["id"]


def create_sticky(content, x, y, color, parent_id=None):
    payload = {
        "data": {"content": content, "shape": "rectangle"},
        "style": {"fillColor": color, "textAlign": "center", "textAlignVertical": "middle"},
        "position": {"x": x, "y": y, "origin": "center"},
    }
    if parent_id:
        payload["parent"] = {"id": parent_id}
    result = api_post("sticky_notes", payload)
    return result["id"]


def create_rect(content, x, y, width, height, fill_color, fill_opacity,
                border_color=None, border_width="1.0", border_opacity="0.3",
                border_style="normal", font_size="20", text_align="left",
                color="#1a1a1a", parent_id=None):
    """汎用の矩形シェイプ作成"""
    payload = {
        "data": {"content": f"<p>{content}</p>" if content else "", "shape": "rectangle"},
        "style": {
            "fillColor": fill_color,
            "fillOpacity": str(fill_opacity),
            "fontFamily": "noto_sans",
            "fontSize": font_size,
            "borderColor": border_color or fill_color,
            "borderWidth": border_width,
            "borderOpacity": border_opacity,
            "borderStyle": border_style,
            "textAlign": text_align,
            "textAlignVertical": "middle",
            "color": color,
        },
        "position": {"x": x, "y": y, "origin": "center"},
        "geometry": {"width": width, "height": height},
    }
    if parent_id:
        payload["parent"] = {"id": parent_id}
    result = api_post("shapes", payload)
    return result["id"]


def parse_story(story):
    """ストーリーを {label, status} に正規化"""
    if isinstance(story, str):
        return {"label": story, "status": "new"}
    return {"label": story.get("label", ""), "status": story.get("status", "new")}


def deploy_usm(usm_data, x_offset=0, y_offset=0):
    title = usm_data["title"]
    backbones = usm_data["backbones"]
    release_lines = usm_data.get("release_lines", [])

    # =============================================
    # Step 1: レイアウト計算
    # =============================================

    content_left = RELEASE_COL_W + 40

    backbone_layouts = []
    current_x = content_left

    for bb in backbones:
        narratives = bb.get("narratives", [])
        max_stories = max((len(n.get("stories", [])) for n in narratives), default=0) if narratives else 0
        num_cols = max(len(narratives), 1)
        bb_width = num_cols * (STICKY_W + COL_GAP) - COL_GAP

        narrative_layouts = []
        for i, narr in enumerate(narratives):
            narr_x = current_x + i * (STICKY_W + COL_GAP) + STICKY_W / 2
            narrative_layouts.append({
                "narrative": narr,
                "x": narr_x,
                "stories": [parse_story(s) for s in narr.get("stories", [])],
            })

        backbone_layouts.append({
            "backbone": bb,
            "x_start": current_x,
            "x_center": current_x + bb_width / 2,
            "width": bb_width,
            "narratives": narrative_layouts,
            "max_stories": max_stories,
        })
        current_x += bb_width + BB_SEPARATOR

    total_width = current_x - BB_SEPARATOR + 80
    max_stories_global = max(bl["max_stories"] for bl in backbone_layouts) if backbone_layouts else 0

    # Y座標計算
    margin_top = 60

    bb_band_y = margin_top
    bb_content_top = bb_band_y + BAND_LABEL_H + SECTION_PAD
    bb_sticky_y = bb_content_top + STICKY_H / 2
    bb_section_bottom = bb_sticky_y + STICKY_H / 2 + SECTION_PAD
    bb_section_h = bb_section_bottom - bb_band_y

    narr_band_y = bb_section_bottom + 20
    narr_content_top = narr_band_y + BAND_LABEL_H + SECTION_PAD
    narr_sticky_y = narr_content_top + STICKY_H / 2
    narr_section_bottom = narr_sticky_y + STICKY_H / 2 + SECTION_PAD
    narr_section_h = narr_section_bottom - narr_band_y

    story_band_y = narr_section_bottom + 20
    story_content_top = story_band_y + BAND_LABEL_H + SECTION_PAD
    story_first_y = story_content_top + STICKY_H / 2

    release_indices = sorted(rl.get("after_story_index", 0) for rl in release_lines)
    release_line_space = 60
    release_extra_space = len(release_lines) * release_line_space

    story_area_h = max_stories_global * STICKY_H + max(max_stories_global - 1, 0) * ROW_GAP + release_extra_space
    story_section_bottom = story_content_top + story_area_h + SECTION_PAD
    story_section_h = story_section_bottom - story_band_y

    total_height = story_section_bottom + 60

    band_full_width = total_width - 40

    # =============================================
    # Step 2: フレーム作成
    # =============================================
    print(f"Creating USM: {title}")
    frame_id = create_frame(
        title,
        x=total_width / 2 + x_offset,
        y=total_height / 2 + y_offset,
        width=total_width,
        height=total_height,
    )
    time.sleep(0.3)

    # Note: 親フレーム付きアイテムは「フレーム左上原点」の相対座標で配置される。
    # したがって子要素の座標には x_offset/y_offset を加えない（フレーム自身に加算済み）。

    # =============================================
    # Step 3: セクション背景（最背面）
    # =============================================
    print("  Creating section backgrounds...")

    create_rect("", total_width / 2, bb_band_y + bb_section_h / 2,
                band_full_width, bb_section_h,
                BAND_COLORS["backbone"], 0.15,
                border_width="1.0", border_opacity="0.1",
                parent_id=frame_id)
    time.sleep(0.1)

    create_rect("", total_width / 2, narr_band_y + narr_section_h / 2,
                band_full_width, narr_section_h,
                BAND_COLORS["narrative"], 0.15,
                border_width="1.0", border_opacity="0.1",
                parent_id=frame_id)
    time.sleep(0.1)

    create_rect("", total_width / 2, story_band_y + story_section_h / 2,
                band_full_width, story_section_h,
                BAND_COLORS["story"], 0.15,
                border_width="1.0", border_opacity="0.1",
                parent_id=frame_id)
    time.sleep(0.1)

    # =============================================
    # Step 4: 帯ラベル（大きめフォント、左寄せ）
    # =============================================
    print("  Creating band labels...")
    create_rect("  バックボーン", total_width / 2, bb_band_y + BAND_LABEL_H / 2,
                band_full_width, BAND_LABEL_H,
                BAND_COLORS["backbone"], 0.6,
                font_size="28", text_align="left", parent_id=frame_id)
    time.sleep(0.1)

    create_rect("  ナラティブ", total_width / 2, narr_band_y + BAND_LABEL_H / 2,
                band_full_width, BAND_LABEL_H,
                BAND_COLORS["narrative"], 0.6,
                font_size="28", text_align="left", parent_id=frame_id)
    time.sleep(0.1)

    create_rect("  ユーザーストーリー", total_width / 2, story_band_y + BAND_LABEL_H / 2,
                band_full_width, BAND_LABEL_H,
                BAND_COLORS["story"], 0.6,
                font_size="28", text_align="left", parent_id=frame_id)
    time.sleep(0.1)

    # =============================================
    # Step 5: Backbone付箋
    # =============================================
    print("  Creating backbones...")
    backbone_ids = {}
    for bi, bl in enumerate(backbone_layouts):
        bb = bl["backbone"]
        bid = create_sticky(bb["label"], bl["x_center"], bb_sticky_y, COLORS["backbone"], frame_id)
        # 座標はフレーム相対。ボード絶対値が必要な場合は x_offset/y_offset を加える
        backbone_ids[bi] = {"id": bid, "x": bl["x_center"], "y": bb_sticky_y,
                            "abs_x": bl["x_center"] + x_offset, "abs_y": bb_sticky_y + y_offset}
        time.sleep(0.1)

    # =============================================
    # Step 6: Narrative付箋 + Story付箋
    # =============================================
    print("  Creating narratives and stories...")
    narrative_ids = {}
    story_ids = {}
    for bi, bl in enumerate(backbone_layouts):
        for ni, nl in enumerate(bl["narratives"]):
            narr = nl["narrative"]
            nid = create_sticky(narr["label"], nl["x"], narr_sticky_y, COLORS["narrative"], frame_id)
            narrative_ids[(bi, ni)] = {"id": nid, "x": nl["x"], "y": narr_sticky_y,
                                       "abs_x": nl["x"] + x_offset, "abs_y": narr_sticky_y + y_offset}
            time.sleep(0.1)

            for j, story in enumerate(nl["stories"]):
                extra_offset = sum(release_line_space for ri in release_indices if j >= ri)
                story_y = story_first_y + j * (STICKY_H + ROW_GAP) + extra_offset

                if story["status"] == "hidden" or not story["label"]:
                    # 付箋を描画しない（行のy座標だけ予約しておく）
                    story_ids[(bi, ni, j)] = {"id": None, "x": nl["x"], "y": story_y,
                                              "abs_x": nl["x"] + x_offset, "abs_y": story_y + y_offset,
                                              "status": "hidden"}
                    continue

                story_color = STORY_COLORS.get(story["status"], STORY_COLORS["new"])
                sid = create_sticky(story["label"], nl["x"], story_y, story_color, frame_id)
                story_ids[(bi, ni, j)] = {"id": sid, "x": nl["x"], "y": story_y,
                                          "abs_x": nl["x"] + x_offset, "abs_y": story_y + y_offset,
                                          "status": story["status"]}
                time.sleep(0.1)

    # =============================================
    # Step 7: リリースライン（左端のRelease列にラベル配置）
    # =============================================
    if release_lines:
        print("  Creating release lines...")
        for rl in release_lines:
            idx = rl.get("after_story_index", 3)
            prev_releases = sum(1 for ri in release_indices if ri < idx)
            prev_offset = prev_releases * release_line_space
            line_y = story_first_y + idx * (STICKY_H + ROW_GAP) - ROW_GAP / 2 + prev_offset

            # 横ライン（薄いオレンジ帯）
            line_width = total_width - RELEASE_COL_W - 60
            line_x = content_left + (total_width - content_left - 40) / 2
            create_rect("", line_x, line_y,
                        line_width, 24,
                        "#ff9d48", 0.25,
                        border_color="#ff9d48", border_width="2.0",
                        border_opacity="0.5", border_style="normal",
                        parent_id=frame_id)
            time.sleep(0.1)

            # Release ラベル（左端列にテキストshape）
            create_rect(rl["label"], RELEASE_COL_W / 2 + 20, line_y,
                        RELEASE_COL_W, 40,
                        "#ff9d48", 0.15,
                        border_color="#ff9d48", border_width="2.0",
                        border_opacity="0.5", border_style="normal",
                        font_size="24", text_align="center",
                        color="#d4630a",
                        parent_id=frame_id)
            time.sleep(0.1)

    print(f"\nDone! USM '{title}' deployed to Miro board.")
    print(f"  https://miro.com/app/board/{BOARD_ID}/")
    print(f"\n  TIP: 背景shapeのロックは Miro上で手動で行ってください")
    print(f"       背景shapeを選択 → 右クリック → Lock")

    return {
        "frame_id": frame_id,
        "total_width": total_width,
        "total_height": total_height,
        "frame_x": total_width / 2 + x_offset,
        "frame_y": total_height / 2 + y_offset,
        "backbones": backbone_ids,
        "narratives": narrative_ids,
        "stories": story_ids,
    }


def main():
    if len(sys.argv) < 2:
        print("Usage: python deploy_usm.py <usm_data.json>")
        sys.exit(1)

    json_path = sys.argv[1]
    with open(json_path) as f:
        usm_data = json.load(f)

    deploy_usm(usm_data)


if __name__ == "__main__":
    main()
