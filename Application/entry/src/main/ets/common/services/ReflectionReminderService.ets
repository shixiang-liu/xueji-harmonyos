// 每晚复盘提醒服务 - 用代理提醒（reminderAgentManager）实现每天定时通知
import { reminderAgentManager } from '@kit.BackgroundTasksKit'
import { notificationManager } from '@kit.NotificationKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { PreferencesUtil } from '../utils/PreferencesUtil'

const PREF_KEY_ENABLED: string = 'reflection_reminder_enabled'
const PREF_KEY_HOUR: string = 'reflection_reminder_hour'
const PREF_KEY_MINUTE: string = 'reflection_reminder_minute'
const PREF_KEY_REMINDER_ID: string = 'reflection_reminder_id'

export class ReflectionReminderService {
  private static instance: ReflectionReminderService | null = null

  private constructor() {}

  static getInstance(): ReflectionReminderService {
    if (!ReflectionReminderService.instance) {
      ReflectionReminderService.instance = new ReflectionReminderService()
    }
    return ReflectionReminderService.instance
  }

  /** 是否启用每晚复盘提醒 */
  async isEnabled(): Promise<boolean> {
    return await PreferencesUtil.get<boolean>(PREF_KEY_ENABLED, false)
  }

  /** 获取当前提醒时间 hour:minute（默认 22:00） */
  async getReminderTime(): Promise<number[]> {
    const hour = await PreferencesUtil.get<number>(PREF_KEY_HOUR, 22)
    const minute = await PreferencesUtil.get<number>(PREF_KEY_MINUTE, 0)
    return [hour, minute]
  }

  /** 启用提醒并设定时间 */
  async enableReminder(hour: number, minute: number): Promise<boolean> {
    try {
      // 先取消旧的
      await this.cancelReminder()

      // 注册新的
      const alarm: reminderAgentManager.ReminderRequestAlarm = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
        hour: hour,
        minute: minute,
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7], // 每天
        actionButton: [
          {
            title: '稍后',
            type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE
          }
        ],
        wantAgent: {
          pkgName: 'com.shixiangliu.xueji',
          abilityName: 'EntryAbility',
          uri: 'reflection://launch'
        },
        title: '今晚 5 分钟复盘',
        content: '跟 AI 聊聊今天学了什么，整理成卡片就睡觉。',
        ringDuration: 3,
        snoozeTimes: 0,
        timeInterval: 0,
        slotType: notificationManager.SlotType.OTHER_TYPES,
        notificationId: 7901
      }

      const reminderId = await reminderAgentManager.publishReminder(alarm)
      console.info('[ReflectionReminder] published id =', reminderId, 'time =', hour + ':' + minute)

      await PreferencesUtil.put(PREF_KEY_ENABLED, true)
      await PreferencesUtil.put(PREF_KEY_HOUR, hour)
      await PreferencesUtil.put(PREF_KEY_MINUTE, minute)
      await PreferencesUtil.put(PREF_KEY_REMINDER_ID, reminderId)
      return true
    } catch (err) {
      const error = err as BusinessError
      console.error('[ReflectionReminder] enable failed:', error.code, error.message)
      return false
    }
  }

  /** 取消提醒 */
  async cancelReminder(): Promise<void> {
    try {
      const id = await PreferencesUtil.get<number>(PREF_KEY_REMINDER_ID, -1)
      if (id !== -1) {
        await reminderAgentManager.cancelReminder(id)
      }
      await PreferencesUtil.put(PREF_KEY_ENABLED, false)
      await PreferencesUtil.put(PREF_KEY_REMINDER_ID, -1)
    } catch (err) {
      console.warn('[ReflectionReminder] cancel failed:', err)
    }
  }

  /** 切换：开启/关闭 */
  async toggle(enabled: boolean, hour?: number, minute?: number): Promise<boolean> {
    if (enabled) {
      const time = await this.getReminderTime()
      const h = hour !== undefined ? hour : time[0]
      const m = minute !== undefined ? minute : time[1]
      return await this.enableReminder(h, m)
    } else {
      await this.cancelReminder()
      return true
    }
  }
}
