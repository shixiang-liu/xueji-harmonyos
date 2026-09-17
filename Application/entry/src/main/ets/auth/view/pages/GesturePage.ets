import { promptAction, router } from '@kit.ArkUI'
import { AuthViewModel } from '../../viewmodel/AuthViewModel'
import { AppColors, AppSizes, AppGradients } from '../../../common/utils/AppTheme'
import { BackIconButton } from '../../../common/components/BackIconButton'

interface GestureNodePoint {
  id: number
  x: number
  y: number
}

const NODE_SIZE: number = 74
const CONNECTOR_SIZE: number = 34
const NODE_RADIUS: number = 34
const BOARD_SIZE: number = NODE_SIZE * 3 + CONNECTOR_SIZE * 2
const GRID_INDEXES: number[] = [0, 1, 2, 3, 4]
const BOARD_POINTS: GestureNodePoint[] = [
  { id: 1, x: NODE_SIZE / 2, y: NODE_SIZE / 2 },
  { id: 2, x: NODE_SIZE + CONNECTOR_SIZE + NODE_SIZE / 2, y: NODE_SIZE / 2 },
  { id: 3, x: NODE_SIZE * 2 + CONNECTOR_SIZE * 2 + NODE_SIZE / 2, y: NODE_SIZE / 2 },
  { id: 4, x: NODE_SIZE / 2, y: NODE_SIZE + CONNECTOR_SIZE + NODE_SIZE / 2 },
  { id: 5, x: NODE_SIZE + CONNECTOR_SIZE + NODE_SIZE / 2, y: NODE_SIZE + CONNECTOR_SIZE + NODE_SIZE / 2 },
  { id: 6, x: NODE_SIZE * 2 + CONNECTOR_SIZE * 2 + NODE_SIZE / 2, y: NODE_SIZE + CONNECTOR_SIZE + NODE_SIZE / 2 },
  { id: 7, x: NODE_SIZE / 2, y: NODE_SIZE * 2 + CONNECTOR_SIZE * 2 + NODE_SIZE / 2 },
  { id: 8, x: NODE_SIZE + CONNECTOR_SIZE + NODE_SIZE / 2, y: NODE_SIZE * 2 + CONNECTOR_SIZE * 2 + NODE_SIZE / 2 },
  { id: 9, x: NODE_SIZE * 2 + CONNECTOR_SIZE * 2 + NODE_SIZE / 2, y: NODE_SIZE * 2 + CONNECTOR_SIZE * 2 + NODE_SIZE / 2 }
]

@Entry
@Component
struct GesturePage {
  @State private mode: string = 'setup'
  @State private email: string = ''
  @State private selectedNodes: number[] = []
  @State private selectedSegments: string[] = []
  @State private helperText: string = ''
  @State private isDrawing: boolean = false
  @State private isSubmitting: boolean = false

  private viewModel: AuthViewModel = new AuthViewModel()

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string> | undefined
    this.mode = params ? (params['mode'] || 'setup') : 'setup'
    this.email = params ? (params['email'] || '') : ''
    this.resetHint()
  }

  private resetHint(): void {
    this.helperText = this.mode === 'setup'
      ? '滑动连接至少 4 个点，设置你的快捷登录手势'
      : '滑动输入已设置的手势'
  }

  private clearPath(): void {
    this.selectedNodes = []
    this.selectedSegments = []
    this.isDrawing = false
    this.resetHint()
  }

  private resolveBridgeNodeId(startId: number, endId: number): number {
    if (startId <= 0 || endId <= 0 || startId === endId) {
      return 0
    }
    const startRow = Math.floor((startId - 1) / 3)
    const startColumn = (startId - 1) % 3
    const endRow = Math.floor((endId - 1) / 3)
    const endColumn = (endId - 1) % 3
    const midRow = (startRow + endRow) / 2
    const midColumn = (startColumn + endColumn) / 2
    const hasBridgeNode = Number.isInteger(midRow) && Number.isInteger(midColumn) &&
      (Math.abs(startRow - endRow) === 2 || Math.abs(startColumn - endColumn) === 2)
    if (!hasBridgeNode) {
      return 0
    }
    return midRow * 3 + midColumn + 1
  }

  private appendNode(nodeId: number): void {
    if (nodeId <= 0 || this.selectedNodes.indexOf(nodeId) >= 0) {
      return
    }

    const nextNodes = [...this.selectedNodes]
    const nextSegments = [...this.selectedSegments]
    if (nextNodes.length > 0) {
      const previousNodeId = nextNodes[nextNodes.length - 1]
      const bridgeNodeId = this.resolveBridgeNodeId(previousNodeId, nodeId)
      if (bridgeNodeId > 0 && nextNodes.indexOf(bridgeNodeId) < 0) {
        nextNodes.push(bridgeNodeId)
        nextSegments.push(`${previousNodeId}-${bridgeNodeId}`)
        nextSegments.push(`${bridgeNodeId}-${nodeId}`)
      } else {
        nextSegments.push(`${previousNodeId}-${nodeId}`)
      }
    }
    nextNodes.push(nodeId)
    this.selectedNodes = nextNodes
    this.selectedSegments = nextSegments
  }

  private getGestureValue(): string {
    return this.selectedNodes.map((item: number) => item.toString()).join('-')
  }

  private getNodeStep(nodeId: number): number {
    const index = this.selectedNodes.indexOf(nodeId)
    return index >= 0 ? index + 1 : 0
  }

  private hasSegment(startId: number, endId: number): boolean {
    return this.selectedSegments.indexOf(`${startId}-${endId}`) >= 0 ||
      this.selectedSegments.indexOf(`${endId}-${startId}`) >= 0
  }

  private resolveNode(touchX: number, touchY: number): number {
    for (let index = 0; index < BOARD_POINTS.length; index++) {
      const node = BOARD_POINTS[index]
      const deltaX = touchX - node.x
      const deltaY = touchY - node.y
      const distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY)
      if (distance <= NODE_RADIUS) {
        return node.id
      }
    }
    return 0
  }

  private captureTouchPoint(event: TouchEvent): void {
    if (!event.touches || event.touches.length === 0) {
      return
    }
    const touch = event.touches[0]
    const nodeId = this.resolveNode(touch.x, touch.y)
    if (nodeId > 0) {
      this.appendNode(nodeId)
    }
  }

  private handleBoardTouch(event: TouchEvent): void {
    if (this.isSubmitting) {
      return
    }

    if (event.type === TouchType.Down) {
      this.clearPath()
      this.isDrawing = true
      this.captureTouchPoint(event)
      return
    }

    if (event.type === TouchType.Move) {
      if (!this.isDrawing) {
        return
      }
      this.captureTouchPoint(event)
      return
    }

    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.isDrawing = false
      if (this.mode === 'login' && this.selectedNodes.length >= 4) {
        this.confirmGesture()
      }
    }
  }

  private async confirmGesture(): Promise<void> {
    if (this.isSubmitting) {
      return
    }
    if (!this.email.trim()) {
      promptAction.showToast({ message: '缺少登录邮箱' })
      return
    }

    const gestureValue = this.getGestureValue()
    const steps = gestureValue ? gestureValue.split('-') : []
    if (steps.length < 4) {
      promptAction.showToast({ message: '手势密码至少连接 4 个点' })
      return
    }

    this.isSubmitting = true
    const result = this.mode === 'setup'
      ? await this.viewModel.saveGesture(this.email, gestureValue)
      : await this.viewModel.loginWithGesture(this.email, gestureValue)
    this.isSubmitting = false
    promptAction.showToast({ message: result.message })
    if (result.success) {
      router.replaceUrl({ url: 'diary/view/pages/HomePage' })
    } else {
      this.helperText = result.message
    }
  }

  private canSubmit(): boolean {
    return this.selectedNodes.length >= 4 && !this.isSubmitting
  }

  @Builder
  private HorizontalConnector(startId: number, endId: number) {
    Row() {
      Row()
        .width(CONNECTOR_SIZE)
        .height(this.hasSegment(startId, endId) ? 6 : 2)
        .borderRadius(AppSizes.RADIUS_FULL)
        .backgroundColor(this.hasSegment(startId, endId) ? AppColors.ACCENT : AppColors.TEXT_HINT)
    }
    .width(CONNECTOR_SIZE)
    .height(NODE_SIZE)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private VerticalConnector(startId: number, endId: number) {
    Column() {
      Column()
        .width(this.hasSegment(startId, endId) ? 6 : 2)
        .height(CONNECTOR_SIZE)
        .borderRadius(AppSizes.RADIUS_FULL)
        .backgroundColor(this.hasSegment(startId, endId) ? AppColors.ACCENT : AppColors.TEXT_HINT)
    }
    .width(NODE_SIZE)
    .height(CONNECTOR_SIZE)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private DiagonalConnector(startId: number, endId: number, reverse: boolean) {
    Stack() {
      if (this.hasSegment(startId, endId)) {
        Column()
          .width(50)
          .height(6)
          .borderRadius(AppSizes.RADIUS_FULL)
          .backgroundColor(AppColors.ACCENT)
          .rotate({ angle: reverse ? -45 : 45, centerX: '50%', centerY: '50%' })
      }
    }
    .width(CONNECTOR_SIZE)
    .height(CONNECTOR_SIZE)
  }

  @Builder
  private GestureNodeItem(nodeId: number) {
    Stack() {
      Column()
        .width(NODE_SIZE)
        .height(NODE_SIZE)
        .borderRadius(NODE_SIZE / 2)
        .backgroundColor(this.getNodeStep(nodeId) > 0 ? AppColors.ACCENT_BG : AppColors.BG_SECONDARY)
        .border({
          width: this.getNodeStep(nodeId) > 0 ? 2 : 1,
          color: this.getNodeStep(nodeId) > 0 ? AppColors.ACCENT : AppColors.BORDER
        })

      Column()
        .width(this.getNodeStep(nodeId) > 0 ? 16 : 12)
        .height(this.getNodeStep(nodeId) > 0 ? 16 : 12)
        .borderRadius(AppSizes.RADIUS_FULL)
        .backgroundColor(this.getNodeStep(nodeId) > 0 ? AppColors.ACCENT : AppColors.TEXT_HINT)
    }
    .width(NODE_SIZE)
    .height(NODE_SIZE)
  }

  @Builder
  private BoardCell(row: number, column: number) {
    if (row % 2 === 0 && column % 2 === 0) {
      this.GestureNodeItem(row / 2 * 3 + column / 2 + 1)
    } else if (row % 2 === 0) {
      this.HorizontalConnector(row / 2 * 3 + (column - 1) / 2 + 1, row / 2 * 3 + (column + 1) / 2 + 1)
    } else if (column % 2 === 0) {
      this.VerticalConnector((row - 1) / 2 * 3 + column / 2 + 1, (row + 1) / 2 * 3 + column / 2 + 1)
    } else {
      Stack() {
        this.DiagonalConnector((row - 1) / 2 * 3 + (column - 1) / 2 + 1, (row + 1) / 2 * 3 + (column + 1) / 2 + 1, false)
        this.DiagonalConnector((row - 1) / 2 * 3 + (column + 1) / 2 + 1, (row + 1) / 2 * 3 + (column - 1) / 2 + 1, true)
      }
      .width(CONNECTOR_SIZE)
      .height(CONNECTOR_SIZE)
    }
  }

  build() {
    Stack() {
      Column()
        .width(260)
        .height(260)
        .linearGradient(AppGradients.SPA_SKY)
        .borderRadius(130)
        .position({ x: -80, y: -90 })
        .opacity(0.5)

      Column()
        .width(210)
        .height(210)
        .linearGradient(AppGradients.SPA_MINT)
        .borderRadius(105)
        .position({ x: 240, y: 70 })
        .opacity(0.5)

      Scroll() {
        Column({ space: 22 }) {
          Row() {
            BackIconButton({
              onBack: () => {
                router.back()
              }
            })
            Blank()
          }
          .width('100%')
          .margin({ top: AppSizes.SPACE_LG })

          Column({ space: 8 }) {
            Text(this.mode === 'setup' ? '设置手势密码' : '手势登录')
              .fontSize(AppSizes.FONT_2XL)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TEXT_PRIMARY)

            Text(this.email || '--')
              .fontSize(AppSizes.FONT_SM)
              .fontColor(AppColors.TEXT_SECONDARY)

            Text(this.helperText)
              .fontSize(AppSizes.FONT_SM)
              .fontColor(AppColors.TEXT_TERTIARY)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column({ space: 18 }) {
            Column() {
              ForEach(GRID_INDEXES, (row: number) => {
                Row() {
                  ForEach(GRID_INDEXES, (column: number) => {
                    this.BoardCell(row, column)
                  }, (column: number) => `${row}-${column}`)
                }
              }, (row: number) => row.toString())
            }
            .width(BOARD_SIZE)
            .height(BOARD_SIZE + 44)
            .justifyContent(FlexAlign.Center)
            .onTouch((event: TouchEvent) => this.handleBoardTouch(event))
          }
          .width('100%')
          .padding({ top: AppSizes.SPACE_LG, bottom: AppSizes.SPACE_MD })
          .backgroundColor(AppColors.BG_GLASS)
          .borderRadius(AppSizes.RADIUS_XL)
          .border({ width: 1, color: AppColors.BORDER_LIGHT })
          .alignItems(HorizontalAlign.Center)

          Row({ space: AppSizes.SPACE_MD }) {
            Button('清空')
              .layoutWeight(1)
              .height(52)
              .fontSize(AppSizes.FONT_MD)
              .fontColor(AppColors.TEXT_PRIMARY)
              .backgroundColor(AppColors.BG_SECONDARY)
              .border({ width: 1, color: AppColors.BORDER })
              .borderRadius(AppSizes.RADIUS_MD)
              .onClick(() => this.clearPath())

            Button(this.mode === 'setup' ? '保存手势' : '验证手势')
              .layoutWeight(1)
              .height(52)
              .fontSize(AppSizes.FONT_MD)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .linearGradient(AppGradients.PRIMARY_BTN)
              .borderRadius(AppSizes.RADIUS_MD)
              .enabled(this.canSubmit())
              .opacity(this.canSubmit() ? 1 : 0.45)
              .onClick(() => this.confirmGesture())
          }
          .width('100%')

          if (this.mode === 'setup') {
            Button('暂时跳过')
              .width('100%')
              .height(46)
              .fontSize(AppSizes.FONT_SM)
              .backgroundColor(Color.Transparent)
              .fontColor(AppColors.TEXT_SECONDARY)
              .onClick(() => router.replaceUrl({ url: 'diary/view/pages/HomePage' }))
          }
        }
        .width('100%')
        .padding({ left: AppSizes.SPACE_LG, right: AppSizes.SPACE_LG, bottom: AppSizes.SPACE_XL })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PRIMARY)
  }
}
