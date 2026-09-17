export const DEFAULT_LEARNING_CATEGORIES: string[] = ['课程', '实验', '复习', '资料', '项目', '复盘', '其他']

export const REFLECTION_CATEGORY: string = '复盘'

export function normalizeLearningCategory(category: string | undefined): string {
  const value = (category || '').trim()
  if (DEFAULT_LEARNING_CATEGORIES.includes(value)) {
    return value
  }
  if (value === '学习') {
    return '课程'
  }
  if (value === '工作') {
    return '项目'
  }
  if (value === '灵感') {
    return '资料'
  }
  if (value.length === 0 || value === '未分类' || value === '生活' || value === '情感' || value === '旅行') {
    return '其他'
  }
  return value
}
