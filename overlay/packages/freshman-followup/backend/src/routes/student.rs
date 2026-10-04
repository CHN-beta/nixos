use axum::{
    extract::{Path, Query, State},
    Json,
};
use chrono::NaiveDate;
use sea_orm::{
    ActiveModelTrait, ColumnTrait, EntityTrait, PaginatorTrait, QueryFilter,
    QueryOrder, QuerySelect, Set, TransactionTrait,
};
use serde::{Deserialize, Serialize};
use serde_json::json;

use crate::{
    audit::record_log,
    auth::CurrentUser,
    entity::{student, teacher_schedule},
    error::AppError,
    state::AppState,
};

const VALID_STATUSES: [&str; 7] = [
    "未联系",
    "空号",
    "未接通",
    "拒绝回访",
    "暂时没空",
    "成功预约",
    "其它",
];

#[derive(Debug, Deserialize)]
pub struct StudentQuery {
    pub search: Option<String>,
    pub college: Option<String>,
    pub status: Option<String>,
    pub page: Option<u64>,
    pub page_size: Option<u64>,
}

#[derive(Debug, Serialize)]
pub struct StudentDetail {
    pub id: String,
    pub name: String,
    pub student_no: String,
    pub phone: String,
    pub college: String,
    pub status: String,
    pub remarks: String,
    pub schedule_id: Option<i32>,
    pub updated_by: Option<String>,
    pub updated_at: chrono::DateTime<chrono::FixedOffset>,
    pub schedule_date: Option<NaiveDate>,
    pub schedule_slot_index: Option<i16>,
    pub schedule_column_index: Option<i16>,
    pub schedule_teacher_name: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct StudentListResponse {
    pub items: Vec<StudentDetail>,
    pub total: u64,
    pub page: u64,
    pub page_size: u64,
}

#[derive(Debug, Deserialize)]
pub struct UpdateStatusRequest {
    pub status: String,
    pub schedule_id: Option<i32>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateRemarksRequest {
    pub remarks: String,
}

pub async fn list_colleges(
    _user: CurrentUser,
    State(state): State<AppState>,
) -> Result<Json<Vec<String>>, AppError> {
    let items = student::Entity::find()
        .select_only()
        .column(student::Column::College)
        .distinct()
        .order_by_asc(student::Column::College)
        .into_tuple::<String>()
        .all(&state.db)
        .await?;

    Ok(Json(items))
}

pub async fn list_students(
    _user: CurrentUser,
    State(state): State<AppState>,
    Query(query): Query<StudentQuery>,
) -> Result<Json<StudentListResponse>, AppError> {
    let page = query.page.unwrap_or(1).max(1);
    let page_size = query.page_size.unwrap_or(20).clamp(1, 100);

    let mut select = student::Entity::find();

    if let Some(ref c) = query.college {
        let trimmed = c.trim();
        if !trimmed.is_empty() {
            select = select.filter(student::Column::College.eq(trimmed));
        }
    }

    if let Some(ref s) = query.status {
        let trimmed = s.trim();
        if !trimmed.is_empty() {
            select = select.filter(student::Column::Status.eq(trimmed));
        }
    }

    if let Some(ref q) = query.search {
        let trimmed = q.trim();
        if !trimmed.is_empty() {
            let pattern = format!("%{}%", trimmed);
            select = select.filter(
                student::Column::Name
                    .like(&pattern)
                    .or(student::Column::StudentNo.like(&pattern))
                    .or(student::Column::Id.like(&pattern)),
            );
        }
    }

    let paginator = select
        .order_by_asc(student::Column::College)
        .order_by_asc(student::Column::StudentNo)
        .paginate(&state.db, page_size);

    let total = paginator.num_items().await?;
    let students = paginator.fetch_page(page - 1).await?;

    // Load schedule info for students that have schedule_id
    let schedule_ids: Vec<i32> = students
        .iter()
        .filter_map(|s| s.schedule_id)
        .collect();

    let schedules_map: std::collections::HashMap<i32, teacher_schedule::Model> =
        if !schedule_ids.is_empty() {
            let schedules = teacher_schedule::Entity::find()
                .filter(teacher_schedule::Column::Id.is_in(schedule_ids))
                .all(&state.db)
                .await?;
            schedules.into_iter().map(|s| (s.id, s)).collect()
        } else {
            std::collections::HashMap::new()
        };

    let items = students
        .into_iter()
        .map(|s| {
            let (schedule_date, schedule_slot_index, schedule_column_index, schedule_teacher_name) =
                if let Some(sid) = s.schedule_id {
                    if let Some(sch) = schedules_map.get(&sid) {
                        (Some(sch.date), Some(sch.slot_index), Some(sch.column_index), Some(sch.teacher_name.clone()))
                    } else {
                        (None, None, None, None)
                    }
                } else {
                    (None, None, None, None)
                };

            StudentDetail {
                id: s.id,
                name: s.name,
                student_no: s.student_no,
                phone: s.phone,
                college: s.college,
                status: s.status,
                remarks: s.remarks,
                schedule_id: s.schedule_id,
                updated_by: s.updated_by,
                updated_at: s.updated_at,
                schedule_date,
                schedule_slot_index,
                schedule_column_index,
                schedule_teacher_name,
            }
        })
        .collect();

    Ok(Json(StudentListResponse {
        items,
        total,
        page,
        page_size,
    }))
}

pub async fn get_student(
    _user: CurrentUser,
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<Json<StudentDetail>, AppError> {
    let s = student::Entity::find_by_id(&id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("学生不存在".to_string()))?;

    let (schedule_date, schedule_slot_index, schedule_column_index, schedule_teacher_name) = if let Some(sid) = s.schedule_id {
        if let Some(sch) = teacher_schedule::Entity::find_by_id(sid).one(&state.db).await? {
            (Some(sch.date), Some(sch.slot_index), Some(sch.column_index), Some(sch.teacher_name))
        } else {
            (None, None, None, None)
        }
    } else {
        (None, None, None, None)
    };

    Ok(Json(StudentDetail {
        id: s.id,
        name: s.name,
        student_no: s.student_no,
        phone: s.phone,
        college: s.college,
        status: s.status,
        remarks: s.remarks,
        schedule_id: s.schedule_id,
        updated_by: s.updated_by,
        updated_at: s.updated_at,
        schedule_date,
        schedule_slot_index,
        schedule_column_index,
        schedule_teacher_name,
    }))
}

pub async fn update_status(
    user: CurrentUser,
    State(state): State<AppState>,
    Path(id): Path<String>,
    Json(payload): Json<UpdateStatusRequest>,
) -> Result<Json<StudentDetail>, AppError> {
    let new_status = payload.status.trim();
    if !VALID_STATUSES.contains(&new_status) {
        return Err(AppError::BadRequest(format!(
            "无效的状态值: {}，可选值: {:?}",
            new_status, VALID_STATUSES
        )));
    }

    // 成功预约强一致性校验
    if new_status == "成功预约" && payload.schedule_id.is_none() {
        return Err(AppError::BadRequest(
            "状态更改为'成功预约'必须指定排班时段".to_string(),
        ));
    }
    if new_status != "成功预约" && payload.schedule_id.is_some() {
        return Err(AppError::BadRequest(
            "非'成功预约'状态不能绑定排班".to_string(),
        ));
    }

    // 开启事务处理排班释放、排班占用与状态更新
    let txn = state.db.begin().await?;

    let student_model = student::Entity::find_by_id(&id)
        .one(&txn)
        .await?
        .ok_or_else(|| AppError::NotFound("学生不存在".to_string()))?;

    let old_status = student_model.status.clone();
    let old_schedule_id = student_model.schedule_id;
    let new_schedule_id = payload.schedule_id;

    // 1. 若学生原已预约，且新状态不是成功预约或换了其他排班，自动释放原排班
    if let Some(old_id) = old_schedule_id {
        if new_status != "成功预约" || Some(old_id) != new_schedule_id {
            teacher_schedule::Entity::update_many()
                .col_expr(
                    teacher_schedule::Column::StudentId,
                    sea_orm::sea_query::Expr::val(None::<String>).into(),
                )
                .filter(teacher_schedule::Column::Id.eq(old_id))
                .filter(teacher_schedule::Column::StudentId.eq(id.clone()))
                .exec(&txn)
                .await?;
        }
    }

    // 2. 若新状态为成功预约且需要占用新排班
    if new_status == "成功预约" {
        let target_schedule_id = new_schedule_id.unwrap();

        // 仅当不同于原排班时需要重新占位
        if Some(target_schedule_id) != old_schedule_id {
            // 原子占用排班：UPDATE teacher_schedules SET student_id = $id WHERE id = $schedule_id AND student_id IS NULL
            let update_res = teacher_schedule::Entity::update_many()
                .col_expr(
                    teacher_schedule::Column::StudentId,
                    sea_orm::sea_query::Expr::val(Some(id.clone())).into(),
                )
                .filter(teacher_schedule::Column::Id.eq(target_schedule_id))
                .filter(teacher_schedule::Column::StudentId.is_null())
                .exec(&txn)
                .await?;

            if update_res.rows_affected == 0 {
                return Err(AppError::Conflict(
                    "该排班已被其他助理抢先预约或不存在，请重新选择空闲排班".to_string(),
                ));
            }
        }
    }

    // 3. 更新学生记录
    let now = chrono::Utc::now().fixed_offset();
    let mut active: student::ActiveModel = student_model.into();
    active.status = Set(new_status.to_string());
    active.schedule_id = Set(new_schedule_id);
    active.updated_by = Set(Some(user.0.clone()));
    active.updated_at = Set(now);

    let updated = active.update(&txn).await?;

    // 4. 插入审计日志
    record_log(
        &txn,
        &user.0,
        json!({
            "action": "update_student_status",
            "student_id": updated.id,
            "student_name": updated.name,
            "old_status": old_status,
            "new_status": updated.status,
            "old_schedule_id": old_schedule_id,
            "new_schedule_id": updated.schedule_id,
        }),
    )
    .await?;

    // 提交事务
    txn.commit().await?;

    // 查询排班详情用于返回
    let (schedule_date, schedule_slot_index, schedule_column_index, schedule_teacher_name) =
        if let Some(sid) = updated.schedule_id {
            if let Some(sch) = teacher_schedule::Entity::find_by_id(sid).one(&state.db).await? {
                (Some(sch.date), Some(sch.slot_index), Some(sch.column_index), Some(sch.teacher_name))
            } else {
                (None, None, None, None)
            }
        } else {
            (None, None, None, None)
        };

    Ok(Json(StudentDetail {
        id: updated.id,
        name: updated.name,
        student_no: updated.student_no,
        phone: updated.phone,
        college: updated.college,
        status: updated.status,
        remarks: updated.remarks,
        schedule_id: updated.schedule_id,
        updated_by: updated.updated_by,
        updated_at: updated.updated_at,
        schedule_date,
        schedule_slot_index,
        schedule_column_index,
        schedule_teacher_name,
    }))
}

pub async fn update_remarks(
    user: CurrentUser,
    State(state): State<AppState>,
    Path(id): Path<String>,
    Json(payload): Json<UpdateRemarksRequest>,
) -> Result<Json<StudentDetail>, AppError> {
    let student_model = student::Entity::find_by_id(&id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("学生不存在".to_string()))?;

    let old_remarks = student_model.remarks.clone();
    let new_remarks = payload.remarks.trim().to_string();

    let now = chrono::Utc::now().fixed_offset();
    let mut active: student::ActiveModel = student_model.into();
    active.remarks = Set(new_remarks.clone());
    active.updated_by = Set(Some(user.0.clone()));
    active.updated_at = Set(now);

    let updated = active.update(&state.db).await?;

    // 审计日志
    record_log(
        &state.db,
        &user.0,
        json!({
            "action": "update_student_remarks",
            "student_id": updated.id,
            "student_name": updated.name,
            "old_remarks": old_remarks,
            "new_remarks": updated.remarks,
        }),
    )
    .await?;

    let (schedule_date, schedule_slot_index, schedule_column_index, schedule_teacher_name) =
        if let Some(sid) = updated.schedule_id {
            if let Some(sch) = teacher_schedule::Entity::find_by_id(sid).one(&state.db).await? {
                (Some(sch.date), Some(sch.slot_index), Some(sch.column_index), Some(sch.teacher_name))
            } else {
                (None, None, None, None)
            }
        } else {
            (None, None, None, None)
        };

    Ok(Json(StudentDetail {
        id: updated.id,
        name: updated.name,
        student_no: updated.student_no,
        phone: updated.phone,
        college: updated.college,
        status: updated.status,
        remarks: updated.remarks,
        schedule_id: updated.schedule_id,
        updated_by: updated.updated_by,
        updated_at: updated.updated_at,
        schedule_date,
        schedule_slot_index,
        schedule_column_index,
        schedule_teacher_name,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_valid_statuses_contains_not_connected() {
        assert!(VALID_STATUSES.contains(&"未接通"));
        assert_eq!(VALID_STATUSES.len(), 7);
    }
}
