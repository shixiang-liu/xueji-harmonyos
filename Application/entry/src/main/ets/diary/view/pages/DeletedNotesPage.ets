/**
 * @file DeletedNotesPage.ets
 * @description 回收站页面 - 显示已删除日记，支持恢复和永久删除
 * @features 30天自动清理、单条恢复、永久删除
 */

import { router, promptAction } from '@kit.ArkUI'
import { NoteItem } from '../../../diary/model/NoteItem'
import { preferences } from '@kit.ArkData'
import common from '@ohos.app.ability.common'
import window from '@ohos.window'
import { AppColors, AppSizes, getCardShadow, AppGradients, AppShadows, LinearGradient } from '../../../common/utils/AppTheme'
import { GlobalAskAIFab } from '../../../common/components/GlobalAskAIFab'

@Entry
@Component
struct DeletedNotesPage {
  // ==================== 状态变量 ====================

  /** 已删除日记列表 */
  @State deletedNotes: NoteItem[] = []

  /** 加载状态 */
  @State isLoading: boolean = true

  /** 顶部安全区高度 */
  @State topSafeHeight: number = 0

  /** 底部安全区高度 */
  @State bottomSafeHeight: number = 0

  /** 已删除日记存储键名 */
  private static readonly DELETED_NOTES_KEY = 'deletedNotes'

  // ==================== 生命周期 ====================

  aboutToAppear() {
    this.setFullScreen()
    this.loadDeletedNotes()
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

  /** 加载已删除日记 */
  async loadDeletedNotes() {
    try {
      this.isLoading = true
      const context = getContext() as common.Context
      const preference = await preferences.getPreferences(context, 'myNotesData')
      const deletedNotesJson = await preference.get(DeletedNotesPage.DELETED_NOTES_KEY, '[]') as string
      const deletedNotes: NoteItem[] = JSON.parse(deletedNotesJson)

      // 过滤超过30天的日记
      const now = Date.now()
      const thirtyDaysInMs = 30 * 24 * 60 * 60 * 1000
      this.deletedNotes = deletedNotes.filter(note => {
        const deletedTime = note.deletedTime || 0
        return (now - deletedTime) < thirtyDaysInMs
      })

      // 如果有被过滤掉的日记，更新存储
      if (this.deletedNotes.length < deletedNotes.length) {
        await this.saveDeletedNotes()
      }

      console.info('[DeletedNotesPage] 加载日记数量:', this.deletedNotes.length)
      this.isLoading = false
    } catch (error) {
      console.error('[DeletedNotesPage] 加载失败:', error)
      this.deletedNotes = []
      this.isLoading = false
    }
  }

  /** 保存已删除日记列表 */
  async saveDeletedNotes() {
    try {
      const context = getContext() as common.Context
      const preference = await preferences.getPreferences(context, 'myNotesData')
      await preference.put(DeletedNotesPage.DELETED_NOTES_KEY, JSON.stringify(this.deletedNotes))
      await preference.flush()
    } catch (error) {
      console.error('[DeletedNotesPage] 保存失败:', error)
    }
  }

  /** 恢复日记 */
  async restoreNote(noteId: string) {
    const noteIndex = this.deletedNotes.findIndex(note => note.id === noteId)
    if (noteIndex >= 0) {
      const noteToRestore = this.deletedNotes[noteIndex]
      noteToRestore.deletedTime = 0

      this.deletedNotes = this.deletedNotes.filter(note => note.id !== noteId)
      await this.saveDeletedNotes()

      // 使用 setOrCreate 确保键存在
      AppStorage.setOrCreate('restoredNote', noteToRestore)
      console.info('[DeletedNotesPage] 设置恢复日记到 AppStorage:', noteToRestore.id)
      promptAction.showToast({ message: '记录已恢复', duration: 2000 })
      router.back()
    }
  }

  /** 永久删除日记 */
  async permanentlyDeleteNote(noteId: string) {
    promptAction.showDialog({
      title: '永久删除',
      message: '确定要永久删除这条记录吗？此操作无法撤销。',
      buttons: [
        { text: '取消', color: AppColors.TEXT_PRIMARY },
        { text: '删除', color: AppColors.ERROR }
      ]
    }).then(async (result) => {
      if (result.index === 1) {
        this.deletedNotes = this.deletedNotes.filter(note => note.id !== noteId)
        await this.saveDeletedNotes()
        promptAction.showToast({ message: '记录已永久删除', duration: 2000 })
      }
    })
  }

  /** 计算剩余保留天数 */
  getRemainingDays(deletedTime: number): number {
    const now = Date.now()
    const thirtyDaysInMs = 30 * 24 * 60 * 60 * 1000
    const elapsed = now - deletedTime
    const remaining = thirtyDaysInMs - elapsed
    const days = Math.ceil(remaining / (24 * 60 * 60 * 1000))
    return days > 0 ? days : 0
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
        // 返回按钮 - 与DetailPage统一设计
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

        Text('回收站')
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
        Text('记录将在 30 天后永久删除')
          .fontSize(AppSizes.FONT_SM)
          .fontColor(AppColors.TEXT_SECONDARY)
      }
      .width('90%')
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
      } else if (this.deletedNotes.length === 0) {
        Column({ space: 8 }) {
          Text('回收站为空')
            .fontSize(AppSizes.FONT_LG)
            .fontColor(AppColors.TEXT_SECONDARY)
          Text('删除的记录会显示在这里')
            .fontSize(AppSizes.FONT_SM)
            .fontColor(AppColors.TEXT_HINT)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.deletedNotes, (note: NoteItem) => {
            ListItem() {
              this.DeletedNoteCard(note)
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

  /** 已删除日记卡片 */
  @Builder DeletedNoteCard(note: NoteItem) {
    Column({ space: 12 }) {
      Column({ space: 4 }) {
        Row() {
          Text(note.title || '无标题')
            .fontSize(AppSizes.FONT_LG)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          Text(`${this.getRemainingDays(note.deletedTime || 0)}天`)
            .fontSize(AppSizes.FONT_XS)
            .fontColor(AppColors.WARNING)
        }
        .width('100%')

        if (note.content) {
          Text(note.content)
            .fontSize(AppSizes.FONT_SM)
            .fontColor(AppColors.TEXT_SECONDARY)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }

      // 操作按钮
      Row({ space: 12 }) {
        Blank()

        Text('恢复')
          .fontSize(AppSizes.FONT_SM)
          .fontColor(AppColors.SUCCESS)
          .fontWeight(FontWeight.Medium)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(AppColors.BG_TERTIARY)
          .borderRadius(AppSizes.RADIUS_XL)
          .onClick(() => this.restoreNote(note.id))

        Text('删除')
          .fontSize(AppSizes.FONT_SM)
          .fontColor(AppColors.WARNING)
          .fontWeight(FontWeight.Medium)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(AppColors.WARNING_BG)
          .borderRadius(AppSizes.RADIUS_XL)
          .onClick(() => this.permanentlyDeleteNote(note.id))
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppColors.BG_SECONDARY)
    .borderRadius(AppSizes.RADIUS_MD)
    .border({ width: 1, color: AppColors.BORDER })
    .shadow(getCardShadow())
  }
}