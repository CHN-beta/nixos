use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "teacher_schedules")]
pub struct Model {
    #[sea_orm(primary_key)]
    pub id: i32,
    pub date: Date,
    pub slot_index: i16,
    pub column_index: i16,
    pub teacher_name: String,
    pub student_id: Option<String>,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {}

impl ActiveModelBehavior for ActiveModel {}
