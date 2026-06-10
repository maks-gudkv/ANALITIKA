import os
import sys

# Фикс для PyInstaller
if getattr(sys, 'frozen', False):
    os.environ['STREAMLIT_WATCHDOG'] = 'false'
    os.environ['STREAMLIT_SERVER_PORT'] = '8501'
    os.environ['STREAMLIT_BROWSER_GATHER_USAGE_STATS'] = 'false'
    os.environ['STREAMLIT_CLIENT_SHOW_ERROR_DETAILS'] = 'true'
    
import streamlit as st
import pandas as pd
import re

st.set_page_config(page_title="Аналитика опроса отделов", layout="wide")
st.title("📊 Аналитика опроса сотрудников по отделам")

uploaded_file = st.file_uploader("Загрузите Excel-файл с опросом", type=["xlsx"])

if uploaded_file:
    df = pd.read_excel(uploaded_file, sheet_name="Оценка УК", header=None)
    headers = df.iloc[0].values
    data = df.iloc[1:].reset_index(drop=True)

    # Колонки с именем, фамилией, рестораном (последние три)
    # Это колонки BJ, BK, BL
    name_col = len(headers) - 3
    surname_col = len(headers) - 2
    restaurant_col = len(headers) - 1

    # ===== ТОЧНАЯ СТРУКТУРА ПО КОЛОНКАМ (из вашей таблицы) =====
    # Формат: "Название": [колонка_вопроса1, колонка_вопроса2, колонка_вопроса3, колонка_комментария, колонка_среднего]

    dept_config = {
        "IT отдел": {
            "questions": [0, 1, 2],
            "comment": 3,
            "avg": 4
        },
        "Отдел кадров": {
            "questions": [5, 6],
            "comment": 7,
            "avg": 8
        },
        "Отдел подбора": {
            "questions": [9, 10, 11],  # 3 вопроса
            "comment": 12,
            "avg": 13
        },
        "Отдел по обучению": {
            "questions": [14, 15, 16],
            "comment": 17,
            "avg": 18
        },
        "Отдел строительства и развития": {
            "questions": [19, 20],
            "comment": 21,
            "avg": 22
        },
        "Отдел бухгалтерии": {
            "questions": [23, 24],
            "comment": 25,
            "avg": 26
        },
        "Отдел по расчету заработной платы": {
            "questions": [27, 28],
            "comment": 29,
            "avg": 30
        },
        "Отдел контроля и качества": {
            "questions": [31, 32, 33],
            "comment": 34,
            "avg": 35
        },
        "Юридический отдел": {
            "questions": [36, 37],
            "comment": 38,
            "avg": 39
        },
        "Отдел эксплуатации": {
            "questions": [40, 41],
            "comment": 42,
            "avg": 43
        },
        "Отдел маркетинга": {
            "questions": [44, 45, 46],
            "comment": 47,
            "avg": 48
        },
        "Финансовый отдел": {
            "questions": [49, 50],
            "comment": 51,
            "avg": 52
        },
        "Отдел логистики": {
            "questions": [53, 54],
            "comment": 55,
            "avg": 56
        },
        "Кондитерский отдел": {
            "questions": [57, 58],  # 2 вопроса
            "comment": 59,
            "avg": 60
        },
    }


    def to_float_rounded(val):
        try:
            num = float(val)
            return round(num, 1)
        except:
            return None


    # Функция для очистки текста вопроса
    def clean_question_text(text):
        if not isinstance(text, str):
            return text
        # Убираем название отдела и квадратные скобки
        cleaned = re.sub(r'^Оценка\s+[^\[]+\[|\]', '', text)
        if not cleaned:
            cleaned = text
        if len(cleaned) > 60:
            cleaned = cleaned[:57] + "..."
        return cleaned


    st.subheader("📈 Средние баллы по отделам")

    results = []
    dept_questions = {}

    for dept_name, cfg in dept_config.items():
        avg_col = cfg["avg"]

        # Проверяем, что колонка существует
        if avg_col >= len(headers):
            st.warning(f"Колонка {avg_col} для отдела '{dept_name}' не найдена")
            continue

        scores = data[avg_col].apply(to_float_rounded).dropna()
        scores = scores[(scores >= 1) & (scores <= 5)]

        if not scores.empty:
            overall_avg = round(scores.mean(), 1)
            count = len(scores)
        else:
            overall_avg = 0
            count = 0

        results.append({
            "Отдел": dept_name,
            "Общий средний балл (все сотрудники)": overall_avg,
            "Количество оценок": count
        })

        # Сохраняем вопросы для детального просмотра
        questions_list = []
        for q_col in cfg["questions"]:
            if q_col < len(headers) and isinstance(headers[q_col], str):
                questions_list.append({
                    "col_idx": q_col,
                    "question_text": headers[q_col]
                })
        dept_questions[dept_name] = questions_list

    results_df = pd.DataFrame(results).sort_values("Общий средний балл (все сотрудники)", ascending=False)
    st.dataframe(results_df, use_container_width=True)

    # Детальные оценки
    st.subheader("📋 Детальные оценки по каждому сотруднику")

    for dept_name, cfg in dept_config.items():
        avg_col = cfg["avg"]
        comment_col = cfg["comment"]
        questions_list = dept_questions.get(dept_name, [])

        # Проверяем существование колонок
        if avg_col >= len(headers):
            continue

        with st.expander(f"🔍 {dept_name} — оценки всех сотрудников"):
            employees_data = []

            for row_idx, row in data.iterrows():
                avg_score = row[avg_col]
                if pd.notna(avg_score):
                    rounded_avg = to_float_rounded(avg_score)
                    if rounded_avg is None or rounded_avg < 1 or rounded_avg > 5:
                        continue

                    name = row[name_col] if pd.notna(row[name_col]) else ""
                    surname = row[surname_col] if pd.notna(row[surname_col]) else ""
                    restaurant = row[restaurant_col] if pd.notna(row[restaurant_col]) else ""

                    # Собираем оценки по вопросам
                    question_scores = {}
                    for q in questions_list:
                        q_col = q["col_idx"]
                        if q_col < len(row):
                            q_score = row[q_col]
                            if pd.notna(q_score):
                                rounded_q = to_float_rounded(q_score)
                                if rounded_q is not None and 1 <= rounded_q <= 5:
                                    clean_text = clean_question_text(q["question_text"])
                                    question_scores[clean_text] = rounded_q

                    # Комментарий
                    comment = ""
                    if comment_col < len(row):
                        if pd.notna(row[comment_col]):
                            comment_raw = str(row[comment_col]).strip()
                            if comment_raw not in ["None", "nan", ""]:
                                comment = comment_raw

                    employees_data.append({
                        "row_idx": row_idx,
                        "Сотрудник": f"{name} {surname}".strip(),
                        "Ресторан": restaurant,
                        "question_scores": question_scores,
                        "comment": comment
                    })

            if employees_data:
                for emp in employees_data:
                    with st.container():
                        col1, col2, col3, col4 = st.columns([3, 2, 1, 1])
                        with col1:
                            st.write(f"**{emp['Сотрудник']}**")
                        with col2:
                            st.write(emp["Ресторан"])
                        with col3:
                            scores_list = [s for s in emp['question_scores'].values() if s is not None]
                            if scores_list:
                                emp_avg = round(sum(scores_list) / len(scores_list), 1)
                                st.write(f"Средний: {emp_avg}")
                            else:
                                st.write("Средний: —")
                        with col4:
                            button_key = f"btn_{dept_name}_{emp['row_idx']}_{emp['Сотрудник']}".replace(" ",
                                                                                                        "_").replace(
                                "(", "").replace(")", "").replace(".", "")
                            if st.button("📋 Подробнее", key=button_key):
                                st.session_state[f"show_{dept_name}_{emp['row_idx']}"] = True

                        if st.session_state.get(f"show_{dept_name}_{emp['row_idx']}", False):
                            with st.container():
                                st.markdown("---")
                                st.markdown(f"### 📌 Подробные оценки: {emp['Сотрудник']}")
                                st.markdown(f"**Отдел:** {dept_name}")

                                st.markdown("**Оценки по вопросам:**")
                                if emp['question_scores']:
                                    for q_text, q_score in emp['question_scores'].items():
                                        st.write(f"- {q_text}: **{q_score}**")
                                else:
                                    st.write("*Нет оценок по вопросам*")

                                if emp["comment"] and emp["comment"] != "":
                                    st.markdown("**💬 Комментарий:**")
                                    st.info(emp["comment"])

                                close_key = f"close_{dept_name}_{emp['row_idx']}_{emp['Сотрудник']}".replace(" ",
                                                                                                             "_").replace(
                                    "(", "").replace(")", "").replace(".", "")
                                if st.button("Закрыть", key=close_key):
                                    st.session_state[f"show_{dept_name}_{emp['row_idx']}"] = False
                                    st.rerun()
                                st.markdown("---")
                st.caption(f"📊 Всего сотрудников: {len(employees_data)}")
            else:
                st.info("Нет оценок")

    # Комментарии
    st.subheader("💬 Комментарии по отделам")

    for dept_name, cfg in dept_config.items():
        comment_col = cfg["comment"]

        if comment_col >= len(headers):
            continue

        comments_list = []
        for row_idx, row in data.iterrows():
            if comment_col < len(row):
                comment = row[comment_col]
                if pd.notna(comment) and str(comment).strip() not in ["None", "nan", ""]:
                    name = row[name_col] if pd.notna(row[name_col]) else ""
                    surname = row[surname_col] if pd.notna(row[surname_col]) else ""
                    restaurant = row[restaurant_col] if pd.notna(row[restaurant_col]) else ""
                    comments_list.append({
                        "Ресторан": restaurant,
                        "Сотрудник": f"{name} {surname}".strip(),
                        "Комментарий": str(comment).strip()
                    })

        if comments_list:
            with st.expander(f"📌 {dept_name} ({len(comments_list)} комментариев)"):
                for c in comments_list:
                    st.markdown(f"**{c['Сотрудник']}** ({c['Ресторан']})")
                    st.write(f"💬 {c['Комментарий']}")
                    st.markdown("---")

    # Проверка на наличие комментариев
    has_comments = False
    for dept_name, cfg in dept_config.items():
        comment_col = cfg["comment"]
        if comment_col < len(headers):
            for row_idx, row in data.iterrows():
                if pd.notna(row[comment_col]) and str(row[comment_col]).strip() not in ["None", "nan", ""]:
                    has_comments = True
                    break

    if not has_comments:
        st.info("👍 Нет комментариев ни по одному отделу")

else:
    st.info("👈 Загрузите Excel-файл, чтобы начать аналитику")
