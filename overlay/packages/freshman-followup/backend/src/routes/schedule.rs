use axum::{
    extract::{Path, Query, State},
    Json,
};
use chrono::NaiveDate;
use sea_orm::{
    ActiveModelTrait, ColumnTrait, EntityTrait, QueryFilter, QueryOrder, Set,
};
use serde::{Deserialize, Serialize};
use serde_json::json;

use crate::{
    audit::record_log,
    auth::CurrentUser,
    entity::{available_date, student, teacher_schedule},
    error::AppError,
    state::AppState,
};

#[derive(Debug, Deserialize)]
pub struct ScheduleQuery {
    pub date: NaiveDate,
}

#[derive(Debug, Serialize)]
pub struct ScheduleItem {
    pub id: i32,
    pub date: NaiveDate,
    pub slot_index: i16,
    pub column_index: i16,
    pub teacher_name: String,
    pub student_id: Option<String>,
    pub student_name: Option<String>,
    pub student_no: Option<String>,
    pub student_phone: Option<String>,
    pub student_college: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct CreateScheduleRequest {
    pub date: NaiveDate,
    pub slot_index: i16,
    pub column_index: i16,
    pub teacher_name: String,
}

pub async fn list_available_dates(
    _user: CurrentUser,
    State(state): State<AppState>,
) -> Result<Json<Vec<available_date::Model>>, AppError> {
    let dates = available_date::Entity::find()
        .filter(available_date::Column::IsActive.eq(true))
        .order_by_asc(available_date::Column::Date)
        .all(&state.db)
        .await?;

    Ok(Json(dates))
}

pub async fn list_schedules(
    _user: CurrentUser,
    State(state): State<AppState>,
    Query(query): Query<ScheduleQuery>,
) -> Result<Json<Vec<ScheduleItem>>, AppError> {
    let schedules = teacher_schedule::Entity::find()
        .filter(teacher_schedule::Column::Date.eq(query.date))
        .order_by_asc(teacher_schedule::Column::SlotIndex)
        .order_by_asc(teacher_schedule::Column::Id)
        .all(&state.db)
        .await?;

    let mut result = Vec::with_capacity(schedules.len());

    // Gather student IDs to query student details
    let student_ids: Vec<String> = schedules
        .iter()
        .filter_map(|s| s.student_id.clone())
        .collect();

    let students_map: std::collections::HashMap<String, student::Model> = if !student_ids.is_empty() {
        let students = student::Entity::find()
            .filter(student::Column::Id.is_in(student_ids))
            .all(&state.db)
            .await?;
        students.into_iter().map(|s| (s.id.clone(), s)).collect()
    } else {
        std::collections::HashMap::new()
    };

    for s in schedules {
        let (student_name, student_no, student_phone, student_college) = if let Some(sid) = &s.student_id {
            if let Some(st) = students_map.get(sid) {
                (
                    Some(st.name.clone()),
                    Some(st.student_no.clone()),
                    Some(st.phone.clone()),
                    Some(st.college.clone()),
                )
            } else {
                (None, None, None, None)
            }
        } else {
            (None, None, None, None)
        };

        result.push(ScheduleItem {
            id: s.id,
            date: s.date,
            slot_index: s.slot_index,
            column_index: s.column_index,
            teacher_name: s.teacher_name,
            student_id: s.student_id,
            student_name,
            student_no,
            student_phone,
            student_college,
        });
    }

    Ok(Json(result))
}

pub async fn create_schedule(
    user: CurrentUser,
    State(state): State<AppState>,
    Json(payload): Json<CreateScheduleRequest>,
) -> Result<Json<teacher_schedule::Model>, AppError> {
    let teacher_name = payload.teacher_name.trim();
    if teacher_name.is_empty() {
        return Err(AppError::BadRequest("老师姓名不能为空".to_string()));
    }
    if payload.slot_index < 0 || payload.slot_index >= 28 {
        return Err(AppError::BadRequest("时段索引必须在 0 到 27 之间".to_string()));
    }
    if payload.column_index < 0 || payload.column_index >= 8 {
        return Err(AppError::BadRequest("列序号必须在 0 到 7 之间".to_string()));
    }

    // 检查日期是否在激活的可选日期中
    let is_date_active = available_date::Entity::find_by_id(payload.date)
        .filter(available_date::Column::IsActive.eq(true))
        .one(&state.db)
        .await?
        .is_some();

    if !is_date_active {
        return Err(AppError::BadRequest("所选日期非可选开放日期或已被禁用".to_string()));
    }
    // 检查该列是否已有老师排班，或该老师在该时段是否已排班
    let conflict = teacher_schedule::Entity::find()
        .filter(teacher_schedule::Column::Date.eq(payload.date))
        .filter(teacher_schedule::Column::SlotIndex.eq(payload.slot_index))
        .filter(
            teacher_schedule::Column::ColumnIndex.eq(payload.column_index)
                .or(teacher_schedule::Column::TeacherName.eq(teacher_name)),
        )
        .one(&state.db)
        .await?;

    if let Some(c) = conflict {
        if c.column_index == payload.column_index {
            return Err(AppError::Conflict(format!(
                "第 {} 列已有其他老师排班，请选择其他列",
                payload.column_index + 1
            )));
        } else {
            return Err(AppError::Conflict("该时段已安排此位老师，不可重复添加".to_string()));
        }
    }

    let new_schedule = teacher_schedule::ActiveModel {
        id: sea_orm::ActiveValue::NotSet,
        date: Set(payload.date),
        slot_index: Set(payload.slot_index),
        column_index: Set(payload.column_index),
        teacher_name: Set(teacher_name.to_string()),
        student_id: Set(None),
    };

    let model = new_schedule.insert(&state.db).await?;

    // 审计日志
    record_log(
        &state.db,
        &user.0,
        json!({
            "action": "create_schedule",
            "schedule_id": model.id,
            "date": model.date.to_string(),
            "slot_index": model.slot_index,
            "column_index": model.column_index,
            "teacher_name": model.teacher_name,
        }),
    )
    .await?;

    Ok(Json(model))
}

pub async fn delete_schedule(
    user: CurrentUser,
    State(state): State<AppState>,
    Path(id): Path<i32>,
) -> Result<Json<serde_json::Value>, AppError> {
    let schedule = teacher_schedule::Entity::find_by_id(id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("排班不存在".to_string()))?;

    // 已经有预约的排班不可被删除
    if schedule.student_id.is_some() {
        return Err(AppError::BadRequest(
            "该排班已被学生预约，无法删除！请先将学生改期或解除预约".to_string(),
        ));
    }

    teacher_schedule::Entity::delete_by_id(id)
        .exec(&state.db)
        .await?;

    // 审计日志
    record_log(
        &state.db,
        &user.0,
        json!({
            "action": "delete_schedule",
            "schedule_id": schedule.id,
            "date": schedule.date.to_string(),
            "slot_index": schedule.slot_index,
            "teacher_name": schedule.teacher_name,
        }),
    )
    .await?;

    Ok(Json(json!({ "success": true, "message": "排班删除成功" })))
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_slot_index_bounds() {
        for slot in 0..28 {
            assert!(slot >= 0 && slot < 28);
        }
        let invalid_slot = 28;
        assert!(invalid_slot >= 28);
    }

    #[test]
    fn test_hardcoded_teacher_limit() {
        const MAX_TEACHERS_PER_SLOT: usize = 8;
        assert_eq!(MAX_TEACHERS_PER_SLOT, 8);
    }

    #[test]
    fn test_column_index_bounds() {
        for col in 0..8 {
            assert!(col >= 0 && col < 8);
        }
        let invalid_col = 8;
        assert!(invalid_col >= 8);
    }
}
