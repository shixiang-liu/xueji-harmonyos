/**
 * @file LockedNotesPage.ets
 * @description 已加锁日记专属页面 - 显示所有加锁的日记
 * @features 密码验证、统一管理、快速解锁
 */

import { router, promptAction } from '@kit.ArkUI'
import { NoteItem } from '../../../diary/model/NoteItem'
import { PreferencesUtil } from '../../../common/utils/PreferencesUtil'
import common from '@ohos.app.ability.common'
import window from '@ohos.window'
import { AppColors, AppSizes, getCardShadow, AppGradients, AppShadows, LinearGradient } from '../../../common/utils/AppTheme'
import { IconPaths } from '../../../common/utils/IconPaths'
import { IconImage } from '../../../common/components/IconImage'
import { GlobalAskAIFab } from '../../../common/components/GlobalAskAIFab'

@Entry
@Component
struct LockedNotesPage {
  // ==================== 状态变量 ====================

  /** 已加锁日记列表 */
  @State lockedNotes: NoteItem[] = []

  /** 加载状态 */
  @State isLoading: boolean = true

  /** 顶部安全区高度 */
  @State topSafeHeight: number = 0

  /** 底部安全区高度 */
  @State bottomSafeHeight: number = 0

  /** 密码输入弹窗 */
  @State showPasswordDialog: boolean = false
  @State passwordInput: string = ''
  @State selectedNoteId: string = ''
  @State passwordAction: string = 'view'

  /** Context */
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext

  // ==================== 生命周期 ====================

  aboutToAppear() {
    this.setFullScreen()
    this.loadLockedNotes()
  }

  /** 设置全屏布局 */
  async setFullScreen() {
    try {
      const windowClass = await window.getLastWindow(getContext(this))
      await windowClass.setWindowLayoutFullScreen(true)
      const avoidArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      this.topSafeHeight = px2vp(avoidArea.topRect.height)
      this.bottomSafeHeight = px2vp(avoidArea.bottomRect.height)
    } catch (e) {
      this.topSafeHeight = 44
      this.bottomSafeHeight = 34
    }
  }

  // ==================== 数据操作 ====================

  /** 加载已加锁日记 */
  async loadLockedNotes() {
    try {
      this.isLoading = true
      const allNotes = await PreferencesUtil.loadNotes(this.context)

      // 过滤出已加锁的日记
      this.lockedNotes = allNotes.filter(note => note.isLocked === true)

      console.info('[LockedNotesPage] 加载已加锁日记数量:', this.lockedNotes.length)
      this.isLoading = false
    } catch (error) {
      console.error('[LockedNotesPage] 加载失败:', error)
      this.lockedNotes = []
      this.isLoading = false
    }
  }

  /** 验证密码并打开日记 */
  async verifyAndOpen(noteId: string) {
    const note = this.lockedNotes.find(n => n.id === noteId)
    if (!note) return

    if (!note.password) {
      promptAction.showToast({ message: '此记录未设置密码', duration: 2000 })
      return
    }

    this.selectedNoteId = noteId
    this.passwordAction = 'view'
    this.passwordInput = ''
    this.showPasswordDialog = true
  }

  /** 确认密码 */
  async confirmPassword() {
    const note = this.lockedNotes.find(n => n.id === this.selectedNoteId)
    if (!note) return

    if (this.passwordInput === note.password) {
      this.showPasswordDialog = false
      this.passwordInput = ''
      if (this.passwordAction === 'unlock') {
        await this.clearNoteLock(note)
      } else {
        // 问题11修复：传递preUnlocked标志，避免DetailPage二次验证
        router.pushUrl({
          url: 'diary/view/pages/DetailPage',
          params: { noteId: this.selectedNoteId, preUnlocked: true }
        })
      }
    } else {
      promptAction.showToast({ message: '密码错误', duration: 2000 })
    }
  }

  /** 解锁记录 */
  async unlockNote(noteId: string) {
    const note = this.lockedNotes.find(n => n.id === noteId)
    if (!note) return

    if (!note.password) {
      promptAction.showToast({ message: '此记录未设置密码，无法验证', duration: 2000 })
      return
    }

    this.selectedNoteId = noteId
    this.passwordAction = 'unlock'
    this.passwordInput = ''
    this.showPasswordDialog = true
  }

  /** 清除记录锁定状态 */
  async clearNoteLock(note: NoteItem) {
    note.isLocked = false
    note.password = ''
    await PreferencesUtil.saveNote(this.context, note)
    await this.loadLockedNotes() // 重新加载列表
    promptAction.showToast({ message: '记录已解锁', duration: 2000 })
  }

  /** 格式化日期 */
  formatDate(timestamp: number): string {
    const date = new Date(timestamp)
    const month = date.getMonth() + 1
    const day = date.getDate()
    const hour = date.getHours()
    const minute = date.getMinutes()
    return `${month}月${day}日 ${hour}:${minute < 10 ? '0' + minute : minute}`
  }

  // ==================== UI构建 ====================

  build() {
    Stack() {
      Column({ space: 0 }) {
        // 顶部安全区
        Column()
          .width('100%')
          .height(this.topSafeHeight)
          .backgroundColor(AppColors.BG_PRIMARY)

        // 头部导航
        Row() {
          // 返回按钮
          Column() {
            Text('‹')
              .fontSize(28)
              .fontColor(AppColors.TEXT_PRIMARY)
              .fontWeight(FontWeight.Normal)
          }
          .width(42)
          .height(42)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .borderRadius(12)
          .backgroundColor(AppColors.BG_SECONDARY)
          .border({ width: 1, color: AppColors.BORDER })
          .onClick(() => router.back())

          Text('隐私记录')
            .fontSize(AppSizes.FONT_XL)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TEXT_PRIMARY)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Column().width(40)
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })

        // 提示信息
        Row() {
          IconImage({ src: $r('app.media.icon_lock'), iconSize: 16, color: AppColors.TEXT_SECONDARY })
          Text(`共 ${this.lockedNotes.length} 条隐私记录`)
            .fontSize(AppSizes.FONT_SM)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ left: 6 })
        }
        .width('90%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .backgroundColor(AppColors.BG_TERTIARY)
        .borderRadius(AppSizes.RADIUS_SM)
        .margin({ top: 8, bottom: 16 })

        // 内容区域
        if (this.isLoading) {
          Column() {
            LoadingProgress().width(32).height(32).color(AppColors.TEXT_HINT)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.lockedNotes.length === 0) {
          Column({ space: 12 }) {
            Column() {
              IconImage({ src: $r('app.media.icon_lock'), iconSize: 36, color: AppColors.TEXT_SECONDARY })
            }
            .width(80)
            .height(80)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .borderRadius(40)
            .backgroundColor(AppColors.BG_TERTIARY)
            Text('暂无隐私记录')
              .fontSize(AppSizes.FONT_LG)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_SECONDARY)
            Text('在记录详情页可以设置隐私锁')
              .fontSize(AppSizes.FONT_SM)
              .fontColor(AppColors.TEXT_HINT)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 10 }) {
            ForEach(this.lockedNotes, (note: NoteItem) => {
              ListItem() {
                this.LockedNoteCard(note)
              }
            }, (note: NoteItem) => note.id)

            ListItem() {
              Column().height(this.bottomSafeHeight + 20)
            }
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16 })
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.BG_PRIMARY)

      // 密码输入弹窗
      if (this.showPasswordDialog) {
        this.PasswordDialog()
      }

      // 全局"问问 AI"悬浮按钮
      Column() {
        GlobalAskAIFab({ bottomOffset: this.bottomSafeHeight + 40 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.End)
      .justifyContent(FlexAlign.End)
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
  }

  /** 已加锁日记卡片 */
  @Builder LockedNoteCard(note: NoteItem) {
    Column({ space: 12 }) {
      Column({ space: 4 }) {
        Row({ space: 8 }) {
          IconImage({ src: $r('app.media.icon_lock'), iconSize: 16, color: AppColors.TEXT_PRIMARY })

          Text(note.title || '无标题')
            .fontSize(AppSizes.FONT_LG)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          Text(note.emotionEmoji || '😐')
            .fontSize(16)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // 日期
        Text(this.formatDate(note.createTime))
          .fontSize(AppSizes.FONT_XS)
          .fontColor(AppColors.TEXT_TERTIARY)
          .width('100%')

        // 内容预览（加密）
        Text('******  内容已加密  ******')
          .fontSize(AppSizes.FONT_SM)
          .fontColor(AppColors.TEXT_TERTIARY)
          .fontStyle(FontStyle.Italic)
          .width('100%')
          .margin({ top: 4 })
      }

      // 操作按钮
      Row({ space: 12 }) {
        Blank()

        Text('查看')
          .fontSize(AppSizes.FONT_SM)
          .fontColor(AppColors.ACCENT)
          .fontWeight(FontWeight.Medium)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(AppColors.BG_TERTIARY)
          .borderRadius(AppSizes.RADIUS_XL)
          .onClick(() => this.verifyAndOpen(note.id))

        Text('解锁')
          .fontSize(AppSizes.FONT_SM)
          .fontColor(AppColors.WARNING)
          .fontWeight(FontWeight.Medium)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(AppColors.WARNING_BG)
          .borderRadius(AppSizes.RADIUS_XL)
          .onClick(() => this.unlockNote(note.id))
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppColors.BG_SECONDARY)
    .borderRadius(AppSizes.RADIUS_MD)
    .border({ width: 1, color: AppColors.BORDER_LIGHT, style: BorderStyle.Dashed })
    .shadow(getCardShadow())
  }

  /** 密码验证弹窗 */
  @Builder PasswordDialog() {
    Stack({ alignContent: Alignment.Center }) {
      // 遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(AppColors.OVERLAY_DARK)
        .onClick(() => {
          this.showPasswordDialog = false
          this.passwordInput = ''
        })

      // 弹窗
      Column({ space: 20 }) {
        Text(this.passwordAction === 'unlock' ? '验证密码' : '请输入密码')
          .fontSize(AppSizes.FONT_LG)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)

        TextInput({ placeholder: this.passwordAction === 'unlock' ? '输入密码以解除锁定' : '请输入密码', text: this.passwordInput })
          .type(InputType.Password)
          .width('100%')
          .height(46)
          .backgroundColor(AppColors.BG_TERTIARY)
          .borderRadius(AppSizes.RADIUS_SM)
          .onChange((value: string) => {
            this.passwordInput = value
          })

        Row({ space: 12 }) {
          Button('取消')
            .layoutWeight(1)
            .height(42)
            .fontSize(AppSizes.FONT_MD)
            .backgroundColor(AppColors.BG_TERTIARY)
            .fontColor(AppColors.TEXT_PRIMARY)
            .borderRadius(AppSizes.RADIUS_MD)
            .onClick(() => {
              this.showPasswordDialog = false
              this.passwordInput = ''
            })

          Button(this.passwordAction === 'unlock' ? '解锁' : '确认')
            .layoutWeight(1)
            .height(42)
            .fontSize(AppSizes.FONT_MD)
            .backgroundColor(AppColors.ACCENT)
            .fontColor(AppColors.TEXT_WHITE)
            .borderRadius(AppSizes.RADIUS_MD)
            .onClick(() => {
              this.confirmPassword()
            })
        }
        .width('100%')
      }
      .width('80%')
      .padding(24)
      .backgroundColor(AppColors.BG_PRIMARY)
      .borderRadius(AppSizes.RADIUS_LG)
      .shadow(AppShadows.SHADOW_LG)
    }
    .width('100%')
    .height('100%')
  }
}
