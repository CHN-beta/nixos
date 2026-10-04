<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-5">
    <!-- Header & Statistics -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4">
      <div>
        <h2 class="text-lg font-bold text-slate-800 flex items-center space-x-2">
          <span>新生回访名单</span>
          <span class="text-xs bg-slate-100 text-slate-600 px-2 py-0.5 rounded-full font-normal">
            共 {{ total }} 人
          </span>
        </h2>
        <p class="text-xs text-slate-500 mt-0.5">支持一键拨打联系、状态修改确认、排班强绑定与备注独立编辑</p>
      </div>

      <button
        @click="refreshData"
        class="self-start sm:self-auto inline-flex items-center space-x-1.5 px-3 py-1.5 rounded-lg border border-slate-200 bg-white text-xs text-slate-600 hover:bg-slate-50 transition-colors shadow-sm"
      >
        <svg class="w-3.5 h-3.5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
        </svg>
        <span>刷新列表</span>
      </button>
    </div>

    <!-- Filter & Search Controls -->
    <div class="bg-white p-3.5 rounded-xl border border-slate-200 shadow-sm mb-4 space-y-3">
      <div class="grid grid-cols-1 sm:grid-cols-12 gap-2.5">
        <!-- Search input -->
        <div class="sm:col-span-5 relative">
          <input
            v-model="searchKeyword"
            @keyup.enter="handleSearch"
            type="text"
            placeholder="搜索姓名、学号或编号..."
            class="w-full pl-8 pr-8 py-2 rounded-lg border border-slate-200 text-xs focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent bg-slate-50/50"
          />
          <svg class="w-4 h-4 text-slate-400 absolute left-2.5 top-2.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
          </svg>
          <button
            v-if="searchKeyword"
            @click="clearSearch"
            class="absolute right-2.5 top-2.5 text-slate-400 hover:text-slate-600"
          >
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>

        <!-- College Filter -->
        <div class="sm:col-span-4">
          <select
            v-model="selectedCollege"
            @change="handleSearch"
            class="w-full py-2 px-3 rounded-lg border border-slate-200 text-xs bg-slate-50/50 focus:outline-none focus:ring-2 focus:ring-emerald-500 text-slate-700"
          >
            <option value="">全部学院</option>
            <option v-for="c in colleges" :key="c" :value="c">{{ c }}</option>
          </select>
        </div>

        <!-- Status Filter -->
        <div class="sm:col-span-3">
          <select
            v-model="selectedStatus"
            @change="handleSearch"
            class="w-full py-2 px-3 rounded-lg border border-slate-200 text-xs bg-slate-50/50 focus:outline-none focus:ring-2 focus:ring-emerald-500 text-slate-700"
          >
            <option value="">全部状态</option>
            <option value="未联系">未联系</option>
            <option value="成功预约">成功预约</option>
            <option value="暂时没空">暂时没空</option>
            <option value="拒绝回访">拒绝回访</option>
            <option value="空号">空号</option>
            <option value="未接通">未接通</option>
            <option value="其它">其它</option>
          </select>
        </div>
      </div>
    </div>

    <!-- Toast Notification -->
    <div
      v-if="toastMessage"
      class="fixed top-16 right-4 z-50 bg-emerald-600 text-white text-xs px-4 py-2.5 rounded-lg shadow-lg flex items-center space-x-2 animate-in fade-in slide-in-from-top-2"
    >
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
      </svg>
      <span>{{ toastMessage }}</span>
    </div>

    <!-- Student Cards List -->
    <div v-if="loading" class="py-16 text-center">
      <div class="inline-block animate-spin rounded-full h-8 w-8 border-4 border-emerald-500 border-t-transparent mb-2"></div>
      <p class="text-xs text-slate-400">加载学生名单中...</p>
    </div>

    <div v-else-if="students.length === 0" class="bg-white rounded-xl border border-slate-200 p-12 text-center text-slate-400 text-xs shadow-sm">
      未找到符合条件的学生记录
    </div>

    <div v-else class="space-y-3">
      <div
        v-for="s in students"
        :key="s.id"
        class="bg-white rounded-xl border transition-all shadow-sm hover:shadow-md p-4 flex flex-col space-y-3"
        :class="s.status === '成功预约' ? 'border-emerald-300 ring-1 ring-emerald-100' : 'border-slate-200'"
      >
        <!-- Top Row: Student info & Status Button -->
        <div class="flex items-start justify-between gap-2">
          <div class="flex items-center space-x-2.5">
            <div class="w-9 h-9 rounded-full bg-emerald-50 border border-emerald-200 text-emerald-700 flex items-center justify-center font-bold text-sm shrink-0">
              {{ s.name.charAt(0) }}
            </div>
            <div>
              <div class="flex items-center space-x-2">
                <span class="text-sm font-bold text-slate-900">{{ s.name }}</span>
                <span class="text-[11px] font-mono text-slate-400">{{ s.student_no }}</span>
                <span class="text-[11px] bg-slate-100 text-slate-600 px-1.5 py-0.2 rounded">
                  {{ s.college }}
                </span>
              </div>
              <div class="text-[10px] text-slate-400 mt-0.5">编号: {{ s.id }}</div>
            </div>
          </div>

          <!-- Status Pill Button (Click to trigger status change flow) -->
          <button
            @click="openStatusModal(s)"
            type="button"
            class="px-2.5 py-1 rounded-full text-xs font-medium border flex items-center space-x-1 transition-all shrink-0 hover:scale-105 active:scale-95 shadow-2xs"
            :class="getStatusBadgeClass(s.status)"
            title="点击更改状态"
          >
            <span>{{ s.status }}</span>
            <svg class="w-3 h-3 opacity-60" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
            </svg>
          </button>
        </div>

        <!-- Middle Row: Phone & Dial action -->
        <div class="flex flex-wrap items-center justify-between gap-2 pt-1 border-t border-slate-100 text-xs">
          <div class="flex items-center space-x-2">
            <span class="text-slate-500">电话:</span>
            <a
              :href="'tel:' + s.phone"
              class="inline-flex items-center space-x-1.5 font-mono text-emerald-700 font-semibold bg-emerald-50 hover:bg-emerald-100 px-2.5 py-1 rounded-md transition-colors"
              title="点击直接拨打电话"
            >
              <svg class="w-3.5 h-3.5 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"></path>
              </svg>
              <span>{{ s.phone }}</span>
              <span class="text-[10px] text-emerald-600 font-normal underline">一键拨号</span>
            </a>
          </div>

          <div v-if="s.updated_by" class="text-[11px] text-slate-400">
            经办人: {{ s.updated_by }} · {{ formatTime(s.updated_at) }}
          </div>
        </div>

        <!-- Appointment Info Box (If status is '成功预约') -->
        <div
          v-if="s.status === '成功预约' && s.schedule_date"
          class="bg-emerald-50/80 border border-emerald-200/80 rounded-lg p-2.5 flex items-center justify-between text-xs text-emerald-900"
        >
          <div class="flex items-center space-x-2">
            <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
            <div>
              <span class="font-bold">已预约排班：</span>
              <span>{{ s.schedule_date }} ({{ formatSlotTime(s.schedule_slot_index) }})</span>
              <span class="ml-2 font-bold bg-white px-2 py-0.5 rounded text-emerald-800 border border-emerald-200">
                {{ s.schedule_column_index !== null && s.schedule_column_index !== undefined ? `第 ${s.schedule_column_index + 1} 列 · ` : '' }}{{ s.schedule_teacher_name }}
              </span>
            </div>
          </div>

          <button
            @click="openSchedulePicker(s)"
            type="button"
            class="text-xs font-medium text-emerald-700 bg-white hover:bg-emerald-100 border border-emerald-300 px-2.5 py-1 rounded transition-colors"
          >
            改期
          </button>
        </div>

        <!-- Remarks section (Independent editing) -->
        <div class="flex items-start justify-between gap-2 bg-slate-50 p-2.5 rounded-lg border border-slate-100 text-xs">
          <div class="flex items-start space-x-1.5 flex-1">
            <span class="text-slate-400 font-medium shrink-0">备注:</span>
            <span v-if="s.remarks" class="text-slate-700 break-words">{{ s.remarks }}</span>
            <span v-else class="text-slate-400 italic">暂无备注，点击右侧编辑添加</span>
          </div>

          <button
            @click="openRemarksModal(s)"
            type="button"
            class="text-slate-500 hover:text-emerald-700 p-1 hover:bg-slate-200/50 rounded transition-colors shrink-0"
            title="编辑备注"
          >
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"></path>
            </svg>
          </button>
        </div>
      </div>
    </div>

    <!-- Pagination -->
    <div v-if="total > 0" class="flex items-center justify-between py-4 text-xs text-slate-500">
      <div>共 {{ total }} 位学生</div>
      <div class="flex space-x-1.5">
        <button
          :disabled="page <= 1"
          @click="changePage(page - 1)"
          class="px-3 py-1.5 rounded-lg border border-slate-200 bg-white text-xs disabled:opacity-40"
        >
          上一页
        </button>
        <span class="px-3 py-1.5 text-xs text-slate-700 font-medium">第 {{ page }} 页</span>
        <button
          :disabled="page * pageSize >= total"
          @click="changePage(page + 1)"
          class="px-3 py-1.5 rounded-lg border border-slate-200 bg-white text-xs disabled:opacity-40"
        >
          下一页
        </button>
      </div>
    </div>

    <!-- Modals -->
    <StatusChangeModal
      v-model="showStatusModal"
      :student="activeStudent"
      @select-success-appointment="handleOpenSchedulePickerForSuccess"
      @success="onStatusSuccess"
    />

    <SchedulePickerModal
      v-model="showSchedulePickerModal"
      :student="activeStudent"
      @success="onScheduleSuccess"
    />

    <EditRemarkModal
      v-model="showRemarkModal"
      :student="activeStudent"
      @success="onRemarkSuccess"
    />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { api } from '../api/client';
import { getSlotTimeRange } from '../utils/color';
import StatusChangeModal from '../components/StatusChangeModal.vue';
import SchedulePickerModal from '../components/SchedulePickerModal.vue';
import EditRemarkModal from '../components/EditRemarkModal.vue';

const students = ref([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(20);
const loading = ref(false);

const colleges = ref([]);
const selectedCollege = ref('');
const selectedStatus = ref('');
const searchKeyword = ref('');

const toastMessage = ref('');

// Modals state
const activeStudent = ref(null);
const showStatusModal = ref(false);
const showSchedulePickerModal = ref(false);
const showRemarkModal = ref(false);

async function loadColleges() {
  try {
    colleges.value = await api.getColleges();
  } catch (err) {
    console.error('Failed to load colleges:', err);
  }
}

async function fetchStudents() {
  loading.value = true;
  try {
    const res = await api.getStudents({
      search: searchKeyword.value,
      college: selectedCollege.value,
      status: selectedStatus.value,
      page: page.value,
      page_size: pageSize.value,
    });
    students.value = res.items;
    total.value = res.total;
  } catch (err) {
    console.error('Failed to load students:', err);
  } finally {
    loading.value = false;
  }
}

function handleSearch() {
  page.value = 1;
  fetchStudents();
}

function clearSearch() {
  searchKeyword.value = '';
  handleSearch();
}

function refreshData() {
  fetchStudents();
}

function changePage(newPage) {
  page.value = newPage;
  fetchStudents();
}

function showToast(msg) {
  toastMessage.value = msg;
  setTimeout(() => {
    toastMessage.value = '';
  }, 3000);
}

function openStatusModal(student) {
  activeStudent.value = student;
  showStatusModal.value = true;
}

function openSchedulePicker(student) {
  activeStudent.value = student;
  showSchedulePickerModal.value = true;
}

function openRemarksModal(student) {
  activeStudent.value = student;
  showRemarkModal.value = true;
}

function handleOpenSchedulePickerForSuccess(student) {
  activeStudent.value = student;
  showSchedulePickerModal.value = true;
}

function onStatusSuccess(updated) {
  showToast(`已成功将 ${updated.name} 的状态更改为「${updated.status}」`);
  fetchStudents();
}

function onScheduleSuccess(updated) {
  showToast(`已成功将 ${updated.name} 预约在 ${updated.schedule_date} ${updated.schedule_teacher_name}`);
  fetchStudents();
}

function onRemarkSuccess(updated) {
  showToast(`学生 ${updated.name} 的备注已更新`);
  fetchStudents();
}

function formatSlotTime(slotIndex) {
  if (slotIndex === null || slotIndex === undefined) return '';
  return getSlotTimeRange(slotIndex);
}

function formatTime(isoStr) {
  if (!isoStr) return '';
  const d = new Date(isoStr);
  return d.toLocaleString('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });
}

function getStatusBadgeClass(status) {
  switch (status) {
    case '成功预约':
      return 'bg-emerald-100 text-emerald-800 border-emerald-300';
    case '未联系':
      return 'bg-slate-100 text-slate-700 border-slate-300';
    case '暂时没空':
      return 'bg-amber-100 text-amber-800 border-amber-300';
    case '拒绝回访':
      return 'bg-rose-100 text-rose-800 border-rose-300';
    case '空号':
      return 'bg-red-100 text-red-800 border-red-300';
    case '未接通':
      return 'bg-orange-100 text-orange-800 border-orange-300';
    default:
      return 'bg-purple-100 text-purple-800 border-purple-300';
  }
}

onMounted(() => {
  loadColleges();
  fetchStudents();
});
</script>
