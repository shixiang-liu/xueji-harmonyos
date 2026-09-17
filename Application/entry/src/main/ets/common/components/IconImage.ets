import { AppColors } from '../utils/AppTheme'

/**
 * 通用图标组件 - 用 Image 渲染 svg 资源，自动居中
 * 解决 Shape() + Path() 在不同容器尺寸下的居中问题
 *
 * 注意：成员名不能用 `size` 或 `scale`，会跟 ArkUI 内置修饰器冲突。
 */
@Component
export struct IconImage {
  @Prop src: Resource
  @Prop iconSize: number = 20
  @Prop color: string = AppColors.TEXT_PRIMARY

  build() {
    Image(this.src)
      .width(this.iconSize)
      .height(this.iconSize)
      .fillColor(this.color)
      .objectFit(ImageFit.Contain)
      .draggable(false)
  }
}
