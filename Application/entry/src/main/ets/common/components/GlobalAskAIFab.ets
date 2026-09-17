import { common } from '@kit.AbilityKit'
import { AskAIStore, AskAIMessage, AskAISession } from '../services/AskAIStore'
import { IconImage } from './IconImage'

/**
 * 全局"问问 AI"悬浮按钮 + 半屏对话 Modal。
 *
 * 用法：在每个主流程页面 build() 顶层（最外层 Stack）作为兄弟节点即可：
 *
 * Stack {
 *   YourPageContent()
 *   GlobalAskAIFab()
 * }
 *
 * 不应放在沉浸式或登录页（如 LinkWebViewPage、MediaPreviewPage、LoginPage）。
 *
 * 特性：
 * - 短按：打开 AI 对话半屏
 * - 长按 350ms：进入拖动模式，松手后位置存 AppStorage 持久化
 * - 多会话：点"+"开新对话，点"≡"看历史会话列表
 * - 不依赖 bindSheet，直接自渲染全屏蒙层（避免 NavDestination 嵌套兼容问题）
 */
@Component
export struct GlobalAskAIFab {
  @StorageLink('askAI_visible') visible: boolean = false
  @StorageLink('askAI_sessions') sessions: AskAISession[] = []
  @StorageLink('askAI_show_history') showHistory: boolean = false
  @StorageLink('askAI_input') input: string = ''
  @StorageLink('askAI_loading') loading: boolean = false
  @StorageLink('askAI_error') errorMsg: string = ''

  /** 拖动累计偏移（vp），持久化到 AppStorage 跨页面/重启保留 */
  @StorageLink('askAI_fabX') fabX: number = 0
  @StorageLink('askAI_fabY') fabY: number = 0

  @State dragDeltaX: number = 0
  @State dragDeltaY: number = 0
  @State isDragging: boolean = false

  /** 默认距右/下偏移（页面初始位置，可被 fabX/fabY 累加覆盖） */
  bottomOffset: number = 96

  aboutToAppear(): void {
    AskAIStore.initIfNeeded()
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      // FAB 按钮
      Column() {
        IconImage({ src: $r('app.media.icon_sparkle'), iconSize: 24, color: '#ffffff' })
      }
      .width(56)
      .height(56)
      .borderRadius(28)
      .backgroundColor(this.isDragging ? '#a9583e' : '#cc785c')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .shadow({
        radius: this.isDragging ? 24 : 16,
        color: 'rgba(204, 120, 92, 0.45)',
        offsetY: 6
      })
      .scale({
        x: this.isDragging ? 1.12 : 1,
        y: this.isDragging ? 1.12 : 1
      })
      .animation({ duration: 180, curve: Curve.Friction })
      .margin({ right: 20, bottom: this.bottomOffset })
      .offset({
        x: this.fabX + this.dragDeltaX,
        y: this.fabY + this.dragDeltaY
      })
      .hitTestBehavior(HitTestMode.Block)
      .onClick(() => {
        if (this.isDragging) return
        AskAIStore.open()
      })
      .gesture(
        GestureGroup(GestureMode.Sequence,
          LongPressGesture({ repeat: false, duration: 350 })
            .onAction(() => {
              this.isDragging = true
            }),
          PanGesture()
            .onActionUpdate((event: GestureEvent) => {
              this.dragDeltaX = event.offsetX
              this.dragDeltaY = event.offsetY
            })
            .onActionEnd(() => {
              this.fabX = this.fabX + this.dragDeltaX
              this.fabY = this.fabY + this.dragDeltaY
              this.dragDeltaX = 0
              this.dragDeltaY = 0
              this.isDragging = false
            })
            .onActionCancel(() => {
              this.dragDeltaX = 0
              this.dragDeltaY = 0
              this.isDragging = false
            })
        )
      )

      // 全屏 Modal（自渲染，不用 bindSheet）
      if (this.visible) {
        this.AskAIModal()
      }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(this.visible ? HitTestMode.Default : HitTestMode.Transparent)
  }

  @Builder
  AskAIModal() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 半透明遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(20, 20, 19, 0.5)')
        .onClick(() => AskAIStore.close())

      // 底部抽屉卡片
      Column({ space: 12 }) {
        // 拖动条
        Column()
          .width(40)
          .height(4)
          .borderRadius(2)
          .backgroundColor('#d6d2c8')
          .margin({ top: 10, bottom: 4 })

        // 标题栏
        Row() {
          if (this.showHistory) {
            // 历史视图标题：返回 + 标题
            Row({ space: 6 }) {
              Text('‹')
                .fontSize(22)
                .fontColor('#141413')
                .fontWeight(FontWeight.Medium)
                .padding({ left: 4, right: 4 })
                .onClick(() => {
                  this.showHistory = false
                })
              Text('历史对话')
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor('#141413')
              Text(`· ${this.sessions.length}`)
                .fontSize(13)
                .fontColor('#8e8b82')
            }
            .alignItems(VerticalAlign.Center)
            .layoutWeight(1)
          } else {
            // 主视图标题：当前会话名
            Row({ space: 8 }) {
              IconImage({ src: $r('app.media.icon_sparkle'), iconSize: 18, color: '#cc785c' })
              Text(this.currentTitle())
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#141413')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
            .alignItems(VerticalAlign.Center)
            .layoutWeight(1)

            // 历史按钮
            Column() {
              Text('≡')
                .fontSize(18)
                .fontColor('#6c6a64')
            }
            .width(36)
            .height(36)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .borderRadius(18)
            .backgroundColor('#f5f0e8')
            .margin({ right: 8 })
            .onClick(() => {
              this.showHistory = true
            })

            // 新对话
            Column() {
              Text('+')
                .fontSize(20)
                .fontColor('#6c6a64')
            }
            .width(36)
            .height(36)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .borderRadius(18)
            .backgroundColor('#f5f0e8')
            .margin({ right: 8 })
            .onClick(() => {
              AskAIStore.newSession()
            })
          }

          Column() {
            IconImage({ src: $r('app.media.icon_close'), iconSize: 18, color: '#6c6a64' })
          }
          .width(36)
          .height(36)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .borderRadius(18)
          .backgroundColor('#f5f0e8')
          .onClick(() => AskAIStore.close())
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 4 })

        if (this.showHistory) {
          this.HistoryView()
        } else {
          this.ChatView()
        }
      }
      .width('100%')
      .height('80%')
      .backgroundColor('#ffffff')
      .borderRadius({ topLeft: 24, topRight: 24 })
      .shadow({ radius: 32, color: 'rgba(0,0,0,0.18)', offsetY: -4 })
    }
    .width('100%')
    .height('100%')
  }

  /** 当前活跃会话标题（sessions[0]） */
  private currentTitle(): string {
    if (!this.sessions || this.sessions.length === 0) return '新对话'
    return this.sessions[0].title || '新对话'
  }

  /** 当前会话消息列表 */
  private currentMessages(): AskAIMessage[] {
    if (!this.sessions || this.sessions.length === 0) return []
    return this.sessions[0].messages || []
  }

  @Builder
  ChatView() {
    // 对话区
    Scroll() {
      Column({ space: 10 }) {
        ForEach(this.currentMessages(), (message: AskAIMessage, index: number) => {
          this.MessageBubble(message)
        }, (message: AskAIMessage, index: number) => `${index}_${message.role}_${message.content.length}`)

        if (this.loading) {
          Row({ space: 8 }) {
            LoadingProgress().width(18).height(18).color('#cc785c')
            Text('AI 思考中…')
              .fontSize(14)
              .fontColor('#6c6a64')
          }
          .alignItems(VerticalAlign.Center)
          .alignSelf(ItemAlign.Start)
          .padding(12)
          .backgroundColor('#faf9f5')
          .borderRadius(14)
        }
      }
      .width('100%')
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Auto)
    .backgroundColor('#faf9f5')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })

    if (this.errorMsg.length > 0) {
      Row({ space: 8 }) {
        IconImage({ src: $r('app.media.icon_close'), iconSize: 14, color: '#c64545' })
        Text(this.errorMsg)
          .fontSize(13)
          .fontColor('#c64545')
          .layoutWeight(1)
      }
      .alignItems(VerticalAlign.Center)
      .width('92%')
      .padding(12)
      .backgroundColor('rgba(198, 69, 69, 0.08)')
      .borderRadius(10)
    }

    // 输入区
    Row({ space: 10 }) {
      TextInput({ text: this.input, placeholder: '继续追问，或问一个新问题' })
        .layoutWeight(1)
        .height(44)
        .fontSize(15)
        .fontColor('#141413')
        .placeholderColor('#a09d96')
        .backgroundColor('#faf9f5')
        .borderRadius(22)
        .border({ width: 1, color: '#e6dfd8' })
        .padding({ left: 14, right: 14 })
        .onChange((v: string) => {
          this.input = v
        })

      Text('发送')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#ffffff')
        .padding({ left: 18, right: 18, top: 12, bottom: 12 })
        .backgroundColor(this.input.trim().length > 0 && !this.loading ? '#cc785c' : '#e6dfd8')
        .borderRadius(22)
        .onClick(() => {
          if (this.input.trim().length > 0 && !this.loading) {
            AskAIStore.send(getContext(this) as common.Context)
          }
        })
    }
    .width('92%')
    .padding({ bottom: 24 })
  }

  @Builder
  HistoryView() {
    Scroll() {
      Column({ space: 8 }) {
        if (this.sessions.length <= 1) {
          // 只有当前会话，没历史
          Column({ space: 10 }) {
            Text('🕒')
              .fontSize(36)
            Text('还没有历史对话')
              .fontSize(15)
              .fontColor('#6c6a64')
            Text('开始问问 AI，对话会自动保存在这里')
              .fontSize(12)
              .fontColor('#a09d96')
          }
          .width('100%')
          .padding({ top: 60, bottom: 60 })
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else {
          ForEach(this.sessions.slice(1), (session: AskAISession, index: number) => {
            this.HistoryRow(session)
          }, (session: AskAISession) => session.id)
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 24 })
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Auto)
    .backgroundColor('#faf9f5')
  }

  @Builder
  HistoryRow(session: AskAISession) {
    Row({ space: 10 }) {
      Column({ space: 4 }) {
        Text(session.title || '新对话')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#141413')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row({ space: 6 }) {
          Text(`${session.messages.length} 条`)
            .fontSize(12)
            .fontColor('#a09d96')
          Text('·')
            .fontSize(12)
            .fontColor('#d6d2c8')
          Text(this.formatTime(session.updatedAt))
            .fontSize(12)
            .fontColor('#a09d96')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .onClick(() => AskAIStore.activateSession(session.id))

      // 删除按钮
      Column() {
        Text('×')
          .fontSize(18)
          .fontColor('#a09d96')
      }
      .width(32)
      .height(32)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .borderRadius(16)
      .onClick(() => AskAIStore.deleteSession(session.id))
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#ffffff')
    .borderRadius(12)
    .border({ width: 1, color: '#ebe6df' })
    .alignItems(VerticalAlign.Center)
  }

  private formatTime(ts: number): string {
    if (!ts) return ''
    const now = Date.now()
    const diff = now - ts
    const day = 24 * 60 * 60 * 1000
    if (diff < 60 * 1000) return '刚刚'
    if (diff < 60 * 60 * 1000) return `${Math.floor(diff / (60 * 1000))} 分钟前`
    if (diff < day) return `${Math.floor(diff / (60 * 60 * 1000))} 小时前`
    if (diff < 7 * day) return `${Math.floor(diff / day)} 天前`
    const d = new Date(ts)
    return `${d.getMonth() + 1}-${d.getDate()}`
  }

  @Builder
  MessageBubble(message: AskAIMessage) {
    Row() {
      if (message.role === 'user') {
        Blank().layoutWeight(1)
      }
      Text(message.content)
        .fontSize(15)
        .fontColor(message.role === 'user' ? '#ffffff' : '#252523')
        .lineHeight(23)
        .copyOption(CopyOptions.LocalDevice)
        .padding(12)
        .backgroundColor(message.role === 'user' ? '#cc785c' : '#ffffff')
        .borderRadius(14)
        .constraintSize({ maxWidth: '82%' })
      if (message.role !== 'user') {
        Blank().layoutWeight(1)
      }
    }
    .width('100%')
  }
}

