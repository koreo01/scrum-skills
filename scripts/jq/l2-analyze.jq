# L2セッション構造解析フィルタ
# 入力: jq -s (slurp) で読み込んだJSONL配列
{
  total_records: length,
  type_counts: (group_by(.type) | map({key: .[0].type, value: length}) | from_entries),

  tool_usage: ([
    .[] | select(.type == "assistant") |
    .message // empty |
    (if type == "array" then .[]
     elif type == "object" then .
     else empty end) |
    select(type == "object") |
    .content // empty |
    (if type == "array" then .[]
     elif type == "string" then empty
     else empty end) |
    select(type == "object" and .type == "tool_use") |
    .name // empty
  ] | group_by(.) | map({key: .[0], value: length}) | from_entries),

  errors: ([
    .[] | select(.type == "assistant") |
    .message // empty |
    (if type == "array" then .[]
     elif type == "object" then .
     else empty end) |
    select(type == "object") |
    .content // empty |
    (if type == "array" then .[]
     elif type == "string" then empty
     else empty end) |
    select(type == "object" and .type == "tool_result" and .is_error == true) |
    .content[:200]
  ] | (if length > 10 then .[:10] + ["...(truncated)"] else . end)),

  frustration_signals: ([
    .[] | select(.type == "user") |
    .message // empty |
    (if type == "array" then .[]
     elif type == "object" then .
     else empty end) |
    select(type == "object") |
    .content // empty |
    (if type == "string" then . else empty end) |
    select(
      test("違う|間違|ダメ|だめ|おかしい|わからな|わかりづら|やり直|もう一度|さっき言った|何度も|繰り返し|wrong|no |not what|again|retry|redo"; "i")
    ) |
    .[:150]
  ] | (if length > 5 then .[:5] + ["...(truncated)"] else . end)),

  ai_titles: ([.[] | select(.type == "ai-title") | .title // empty] | unique),

  models: ([.[] | select(.type == "assistant") | .model // empty] | unique),

  cwd: ([.[] | select(.type == "system") | .cwd // empty] | first // null),

  first_timestamp: ([.[] | .timestamp // empty | select(. != null)] | first // null),
  last_timestamp: ([.[] | .timestamp // empty | select(. != null)] | last // null),

  # トリガー検出（§5.3.2）
  triggers: {
    # T1: 同じ質問の繰り返し — 短文ユーザーメッセージ（<100文字）の重複が3回以上
    repeated_questions: (
      [
        .[] | select(.type == "user") |
        .message // empty |
        (if type == "array" then .[]
         elif type == "object" then .
         else empty end) |
        select(type == "object") |
        .content // empty |
        (if type == "string" then . else empty end) |
        select(length < 100 and length > 0)
      ] |
      group_by(.) | map(select(length >= 3) | {text: .[0][:80], count: length}) |
      {detected: (length > 0), count: length, details: .}
    ),

    # T2: ツールエラーの繰り返し — is_error: true が3回以上
    repeated_tool_errors: (
      [
        .[] | select(.type == "assistant") |
        .message // empty |
        (if type == "array" then .[]
         elif type == "object" then .
         else empty end) |
        select(type == "object") |
        .content // empty |
        (if type == "array" then .[]
         elif type == "string" then empty
         else empty end) |
        select(type == "object" and .type == "tool_result" and .is_error == true) |
        .content[:100]
      ] | {detected: (length >= 3), count: length, details: (if length > 5 then .[:5] else . end)}
    ),

    # T3: セッション途中放棄 — last-prompt ありだが assistant メッセージが極少（<3）
    session_abandoned: (
      {
        has_last_prompt: ([.[] | select(.type == "last-prompt")] | length > 0),
        assistant_count: ([.[] | select(.type == "assistant")] | length)
      } |
      {detected: (.has_last_prompt and .assistant_count < 3), assistant_count: .assistant_count}
    ),

    # T4: コンテキスト肥大 — input_tokens の最大値が初期値の5倍以上
    context_bloat: (
      [
        .[] | select(.type == "assistant") |
        .message // empty |
        (if type == "array" then .[]
         elif type == "object" then .
         else empty end) |
        select(type == "object") |
        .usage // empty |
        .input_tokens // empty |
        select(. > 100)
      ] |
      if length >= 2 then
        {
          first_tokens: .[0],
          max_tokens: max,
          ratio: ((max / .[0]) * 100 | floor / 100),
          detected: ((max / .[0]) >= 5)
        }
      else
        {first_tokens: (first // null), max_tokens: (max // null), ratio: null, detected: false}
      end
    ),

    # T5: 出力フォーマット不満 — 短文（<200文字）でフォーマット不満キーワードを含む
    output_dissatisfaction: (
      [
        .[] | select(.type == "user") |
        .message // empty |
        (if type == "array" then .[]
         elif type == "object" then .
         else empty end) |
        select(type == "object") |
        .content // empty |
        (if type == "string" then . else empty end) |
        select(length < 200 and length > 0) |
        select(
          test("見にくい|読みにくい|わかりづらい|わかりにくい|見づらい|違うフォーマット|違う形式|フォーマットが|形式が|整形して|見やすく|読みやすく"; "i")
        ) |
        .[:150]
      ] | {detected: (length > 0), count: length, details: (if length > 3 then .[:3] else . end)}
    )
  }
}
