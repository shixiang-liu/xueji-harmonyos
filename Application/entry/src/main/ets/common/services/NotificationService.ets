/**
 * @file NotificationService.ets
 * @description 本地通知服务 - 用于发送验证码等通知
 */
import { notificationManager } from '@kit.NotificationKit'
import { BusinessError } from '@kit.BasicServicesKit'

export class NotificationService {
  private static instance: NotificationService | null = null
  private isEnabled: boolean = false

  private constructor() {}

  static getInstance(): NotificationService {
    if (!NotificationService.instance) {
      NotificationService.instance = new NotificationService()
    }
    return NotificationService.instance
  }

  /**
   * 请求通知权限
   */
  async requestPermission(): Promise<boolean> {
    try {
      const result = await notificationManager.isNotificationEnabled()
      if (result) {
        this.isEnabled = true
        return true
      }
      // 请求权限
      await notificationManager.requestEnableNotification()
      this.isEnabled = true
      return true
    } catch (err) {
      const error = err as BusinessError
      console.error('[NotificationService] Request permission failed:', error.code, error.message)
      this.isEnabled = false
      return false
    }
  }

  /**
   * 发送验证码通知
   * @param code 验证码
   */
  async sendVerificationCodeNotification(code: string): Promise<boolean> {
    if (!this.isEnabled) {
      const hasPermission = await this.requestPermission()
      if (!hasPermission) {
        console.warn('[NotificationService] No notification permission')
        return false
      }
    }

    try {
      const notificationRequest: notificationManager.NotificationRequest = {
        id: Date.now() % 100000,  // 使用时间戳生成唯一ID
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: '智学 OS 验证码',
            text: `您的验证码是：${code}，5分钟内有效。`,
            additionalText: '请勿泄露给他人'
          }
        },
        notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION
      }

      await notificationManager.publish(notificationRequest)
      console.info('[NotificationService] Verification code notification sent:', code)
      return true
    } catch (err) {
      const error = err as BusinessError
      console.error('[NotificationService] Send notification failed:', error.code, error.message)
      return false
    }
  }

  /**
   * 发送通用通知
   * @param title 标题
   * @param content 内容
   */
  async sendNotification(title: string, content: string): Promise<boolean> {
    if (!this.isEnabled) {
      const hasPermission = await this.requestPermission()
      if (!hasPermission) {
        return false
      }
    }

    try {
      const notificationRequest: notificationManager.NotificationRequest = {
        id: Date.now() % 100000,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: content
          }
        }
      }

      await notificationManager.publish(notificationRequest)
      return true
    } catch (err) {
      console.error('[NotificationService] Send notification failed:', err)
      return false
    }
  }
}
