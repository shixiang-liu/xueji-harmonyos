import { router, promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { ConfigurationConstant } from '@kit.AbilityKit'
import { AuthViewModel } from '../../../auth/viewmodel/AuthViewModel'
import { IconImage } from '../../../common/components/IconImage'
import { AvatarStore, AVATAR_PRESETS } from '../../../common/services/AvatarStore'
import { PreferencesUtil } from '../../../common/utils/PreferencesUtil'
import { AppColors, AppThemeManager } from '../../../common/utils/AppTheme'

/**
 * 用 AppStorage('profile_sheet_visible') 控制可见性。
 * 任何页面 AppStorage.set('profile_sheet_visible', true) 就能弹起。
 */
@Component
export struct ProfileSheet {
  @StorageLink('profile_sheet_visible') visible: boolean = false
  @StorageLink('isDarkMode') isDarkMode: boolean = false
  @StorageProp('currentUserAvatar') avatarUri: string = ''
  @StorageProp('currentUserNickname') currentUserNickname: string = ''

  @State school: string = '陕西师范大学'
  @State studentId: string = '20230001'
  @State showEditProfileDialog: boolean = false
  @State editName: string = ''
  @State editSchool: string = ''
  @State editStudentId: string = ''

  @State isLoggingOut: boolean = false

  async aboutToAppear(): Promise<void> {
    await this.loadProfile()
  }

  build() {
    if (this.visible) {
      Stack({ alignContent: Alignment.Bottom }) {
        // 半透明遮罩
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(AppColors.OVERLAY_DARK)
          .onClick(() => {
            this.visible = false
          })

        // 底部抽屉
        Column({ space: 16 }) {
          // 拖动条
          Column()
            .width(40)
            .height(4)
            .borderRadius(2)
            .backgroundColor(AppColors.TEXT_TERTIARY)
            .margin({ top: 12 })

          // 当前头像 + 姓名
          Column({ space: 6 }) {
            this.CurrentAvatar()

            Text(this.displayName())
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TEXT_PRIMARY)
              .margin({ top: 6 })

            Text(`${this.school} · ${this.studentId}`)
              .fontSize(13)
              .fontColor(AppColors.TEXT_TERTIARY)
          }
          .width('100%')

          Row() {
            Text('编辑资料')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.ACCENT)
          }
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .backgroundColor(AppColors.ACCENT_BG)
          .borderRadius(14)
          .onClick(() => this.openEditProfileDialog())

          // 预设头像 + 自定义按钮
          Column({ space: 10 }) {
            Row() {
              Text('换个头像')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.TEXT_SECONDARY)
                .layoutWeight(1)

              Row({ space: 4 }) {
                IconImage({ src: $r('app.media.icon_camera'), iconSize: 13, color: AppColors.ACCENT })
                Text('从相册选')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColors.ACCENT)
              }
              .alignItems(VerticalAlign.Center)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor(AppColors.ACCENT_BG)
              .borderRadius(12)
              .onClick(() => this.handlePickAvatar())
            }
            .width('92%')
            .alignItems(VerticalAlign.Center)

            // 6 个预设头像
            Row({ space: 12 }) {
              ForEach(AVATAR_PRESETS, (preset: Resource, index: number) => {
                this.PresetChip(preset, index)
              }, (preset: Resource, index: number) => `preset_${index}`)
            }
            .width('92%')
            .justifyContent(FlexAlign.SpaceBetween)
          }
          .width('100%')
          .padding({ top: 4 })

          Divider()
            .strokeWidth(1)
            .color(AppColors.DIVIDER)
            .width('86%')
            .margin({ top: 4 })

          // 深浅色切换
          Row() {
            Text('深色模式')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)

            Blank()

            Toggle({ type: ToggleType.Switch, isOn: this.isDarkMode })
              .onChange((isOn: boolean) => {
                this.isDarkMode = isOn
                AppThemeManager.setIsDarkMode(isOn)
                PreferencesUtil.put('isDarkMode', isOn)
                try {
                  const appCtx = getContext(this).getApplicationContext()
                  appCtx.setColorMode(isOn
                    ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
                    : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
                } catch (err) {
                  console.warn('[ProfileSheet] setColorMode 失败:', err)
                }
              })
          }
          .width('92%')
          .padding(14)
          .alignItems(VerticalAlign.Center)

          // 隐私/回收站 入口
          Column({ space: 10 }) {
            this.LockedEntryRow()
            this.DeletedEntryRow()
          }
          .width('92%')

          // 退出账号
          Row() {
            Column() {
              IconImage({ src: $r('app.media.icon_unlock'), iconSize: 18, color: AppColors.ERROR })
            }
            .width(36)
            .height(36)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .borderRadius(10)
            .backgroundColor(AppColors.ERROR_BG)

            Column({ space: 2 }) {
              Text('退出账号 / 切换账号')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.ERROR)
              Text('回到登录页，本地数据不会被清空')
                .fontSize(12)
                .fontColor(AppColors.TEXT_TERTIARY)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .margin({ left: 12 })

            if (this.isLoggingOut) {
              LoadingProgress().width(20).height(20).color(AppColors.ERROR)
            } else {
              Text('›').fontSize(20).fontColor(AppColors.TEXT_TERTIARY)
            }
          }
          .width('92%')
          .padding(14)
          .backgroundColor(AppColors.BG_PRIMARY)
          .borderRadius(14)
          .border({ width: 1, color: AppColors.DIVIDER })
          .alignItems(VerticalAlign.Center)
          .onClick(() => this.confirmLogout())

          // 关于
          Row() {
            Text('学迹 · HarmonyOS 多媒体学习记录')
              .fontSize(12)
              .fontColor(AppColors.TEXT_TERTIARY)
              .layoutWeight(1)
            Text('v1.0')
              .fontSize(12)
              .fontColor(AppColors.TEXT_TERTIARY)
          }
          .width('92%')
          .padding({ top: 4, bottom: 24 })
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .backgroundColor(AppColors.BG_SECONDARY)
        .borderRadius({ topLeft: 24, topRight: 24 })
        .shadow({ radius: 32, color: 'rgba(0,0,0,0.18)', offsetY: -4 })

        if (this.showEditProfileDialog) {
          this.EditProfileDialog()
        }
      }
      .width('100%')
      .height('100%')
    }
  }

  /** 当前头像（80px 大圆） */
  @Builder
  CurrentAvatar() {
    if (this.avatarUri.startsWith('file://')) {
      Image(this.avatarUri)
        .width(80)
        .height(80)
        .borderRadius(40)
        .objectFit(ImageFit.Cover)
        .alt($r('app.media.user_dark'))
        .shadow({ radius: 16, color: 'rgba(20,20,19,0.16)', offsetY: 4 })
    } else {
      Image(this.currentPresetResource())
        .width(80)
        .height(80)
        .borderRadius(40)
        .objectFit(ImageFit.Cover)
        .backgroundColor(AppColors.BG_SECONDARY)
        .shadow({ radius: 16, color: 'rgba(20,20,19,0.16)', offsetY: 4 })
    }
  }

  @Builder
  PresetChip(preset: Resource, index: number) {
    Stack() {
      Image(preset)
        .width(48)
        .height(48)
        .borderRadius(24)
        .objectFit(ImageFit.Cover)
        .backgroundColor(AppColors.BG_SECONDARY)
        .border(this.isPresetActive(index)
          ? { width: 3, color: AppColors.ACCENT }
          : { width: 0, color: 'transparent' })

      // 选中标记
      if (this.isPresetActive(index)) {
        Column() {
          Text('✓')
            .fontSize(12)
            .fontColor(AppColors.TEXT_WHITE)
            .fontWeight(FontWeight.Bold)
        }
        .width(18)
        .height(18)
        .borderRadius(9)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(AppColors.ACCENT)
        .border({ width: 2, color: AppColors.BG_SECONDARY })
        .position({ x: 33, y: 33 })
      }
    }
    .width(52)
    .height(52)
    .onClick(() => this.handlePickPreset(index))
  }

  private currentPresetResource(): Resource {
    const parsed = AvatarStore.parse(this.avatarUri)
    if (parsed.kind === 'preset' && parsed.presetIdx >= 0 && parsed.presetIdx < AVATAR_PRESETS.length) {
      return AVATAR_PRESETS[parsed.presetIdx]
    }
    return AVATAR_PRESETS[0]
  }

  private isPresetActive(index: number): boolean {
    const parsed = AvatarStore.parse(this.avatarUri)
    if (parsed.kind === 'preset') return parsed.presetIdx === index
    if (parsed.kind === 'default') return index === 0
    return false
  }

  private async handlePickPreset(index: number): Promise<void> {
    const ctx = getContext(this) as common.Context
    await AvatarStore.setPreset(ctx, index)
  }

  private async handlePickAvatar(): Promise<void> {
    const ctx = getContext(this) as common.Context
    const ok = await AvatarStore.pick(ctx)
    if (ok) {
      promptAction.showToast({ message: '头像已更新', duration: 1200 })
    }
  }

  @Builder
  EditProfileDialog() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(20, 20, 19, 0.28)')
        .onClick(() => {
          this.showEditProfileDialog = false
        })

      Column({ space: 14 }) {
        Text('编辑资料')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)

        this.ProfileInput('昵称', this.editName, '输入昵称', (value: string) => {
          this.editName = value
        })
        this.ProfileInput('学校', this.editSchool, '输入学校', (value: string) => {
          this.editSchool = value
        })
        this.ProfileInput('学号', this.editStudentId, '输入学号', (value: string) => {
          this.editStudentId = value
        })

        Row({ space: 10 }) {
          Text('取消')
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 11, bottom: 11 })
            .backgroundColor(AppColors.BG_SECONDARY)
            .borderRadius(12)
            .onClick(() => {
              this.showEditProfileDialog = false
            })

          Text('保存')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_WHITE)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 11, bottom: 11 })
            .backgroundColor(AppColors.ACCENT)
            .borderRadius(12)
            .onClick(() => this.saveProfile())
        }
        .width('100%')
        .margin({ top: 4 })
      }
      .width('82%')
      .padding(20)
      .backgroundColor(AppColors.BG_SECONDARY)
      .borderRadius(18)
      .shadow({ radius: 28, color: 'rgba(0,0,0,0.18)', offsetY: 6 })
    }
    .width('100%')
    .height('100%')
    .zIndex(20)
  }

  @Builder
  ProfileInput(label: string, value: string, placeholder: string, onChange: (value: string) => void) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(12)
        .fontColor(AppColors.TEXT_TERTIARY)
        .width('100%')
      TextInput({ text: value, placeholder: placeholder })
        .width('100%')
        .height(44)
        .fontSize(14)
        .fontColor(AppColors.TEXT_PRIMARY)
        .backgroundColor(AppColors.BG_PRIMARY)
        .borderRadius(12)
        .border({ width: 1, color: AppColors.DIVIDER })
        .padding({ left: 12, right: 12 })
        .onChange(onChange)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  private displayName(): string {
    const name = (this.currentUserNickname || '').trim()
    return name.length > 0 ? name : '学迹用户'
  }

  private async loadProfile(): Promise<void> {
    try {
      const savedSchool = await PreferencesUtil.get<string>('profile_school', this.school)
      const savedStudentId = await PreferencesUtil.get<string>('profile_student_id', this.studentId)
      this.school = savedSchool || this.school
      this.studentId = savedStudentId || this.studentId
    } catch (err) {
      console.warn('[ProfileSheet] 加载资料失败:', JSON.stringify(err))
    }
  }

  private openEditProfileDialog(): void {
    this.editName = this.displayName()
    this.editSchool = this.school
    this.editStudentId = this.studentId
    this.showEditProfileDialog = true
  }

  private async saveProfile(): Promise<void> {
    const name = this.editName.trim()
    const school = this.editSchool.trim()
    const studentId = this.editStudentId.trim()
    if (!name || !school || !studentId) {
      promptAction.showToast({ message: '资料不能为空', duration: 1200 })
      return
    }

    try {
      this.school = school
      this.studentId = studentId
      AppStorage.setOrCreate('currentUserNickname', name)
      await PreferencesUtil.put('currentUserNickname', name)
      await PreferencesUtil.put('profile_school', school)
      await PreferencesUtil.put('profile_student_id', studentId)
      this.showEditProfileDialog = false
      promptAction.showToast({ message: '资料已保存', duration: 1200 })
    } catch (err) {
      console.error('[ProfileSheet] 保存资料失败:', JSON.stringify(err))
      promptAction.showToast({ message: '保存失败，请重试', duration: 1500 })
    }
  }

  @Builder
  LockedEntryRow() {
    Row() {
      Column() {
        IconImage({ src: $r('app.media.icon_lock'), iconSize: 18, color: AppColors.ACCENT })
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .borderRadius(10)
      .backgroundColor(AppColors.ACCENT_BG)

      Column({ space: 2 }) {
        Text('隐私日记')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
        Text('查看已加锁的日记')
          .fontSize(12)
          .fontColor(AppColors.TEXT_TERTIARY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })

      Text('›').fontSize(20).fontColor(AppColors.TEXT_TERTIARY)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppColors.BG_PRIMARY)
    .borderRadius(14)
    .border({ width: 1, color: AppColors.DIVIDER })
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.openLockedNotes())
  }

  @Builder
  DeletedEntryRow() {
    Row() {
      Column() {
        IconImage({ src: $r('app.media.icon_delete'), iconSize: 18, color: AppColors.TEXT_TERTIARY })
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .borderRadius(10)
      .backgroundColor(AppColors.BG_TERTIARY)

      Column({ space: 2 }) {
        Text('回收站')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
        Text('已删除的日记可在此恢复')
          .fontSize(12)
          .fontColor(AppColors.TEXT_TERTIARY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })

      Text('›').fontSize(20).fontColor(AppColors.TEXT_TERTIARY)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppColors.BG_PRIMARY)
    .borderRadius(14)
    .border({ width: 1, color: AppColors.DIVIDER })
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.openDeletedNotes())
  }

  private openLockedNotes(): void {
    this.visible = false
    setTimeout(() => {
      router.pushUrl({ url: 'diary/view/pages/LockedNotesPage' })
    }, 200)
  }

  private openDeletedNotes(): void {
    this.visible = false
    setTimeout(() => {
      router.pushUrl({ url: 'diary/view/pages/DeletedNotesPage' })
    }, 200)
  }

  private confirmLogout(): void {
    AlertDialog.show({
      title: '退出账号',
      message: '退出后可以登录其他账号，本地学习记录不会被清空。',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: { value: '取消', fontColor: AppColors.TEXT_SECONDARY, action: () => {} },
      secondaryButton: { value: '退出', fontColor: AppColors.ERROR, action: () => this.doLogout() }
    })
  }

  private async doLogout(): Promise<void> {
    if (this.isLoggingOut) return
    this.isLoggingOut = true
    try {
      await new AuthViewModel().logout()
      promptAction.showToast({ message: '已退出账号', duration: 1200 })
      this.visible = false
      router.replaceUrl({ url: 'auth/view/pages/LoginPage' })
    } catch (error) {
      console.error('[ProfileSheet] 退出账号失败:', error)
      promptAction.showToast({ message: '退出失败，请重试', duration: 1500 })
    } finally {
      this.isLoggingOut = false
    }
  }
}
