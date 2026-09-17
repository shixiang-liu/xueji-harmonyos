import { common } from '@kit.AbilityKit'
import { fileIo, fileUri } from '@kit.CoreFileKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { util } from '@kit.ArkTS'

/** 预设头像（资源 ID 数组，对应 resources/base/media/avatar_1..6.png） */
export const AVATAR_PRESETS: Resource[] = [
  $r('app.media.avatar_1'),
  $r('app.media.avatar_2'),
  $r('app.media.avatar_3'),
  $r('app.media.avatar_4'),
  $r('app.media.avatar_5'),
  $r('app.media.avatar_6')
]

/** 头像解析结果 */
export class AvatarParseResult {
  kind: string = 'default'
  presetIdx: number = 0
  uri: string = ''
  constructor(kind: string, presetIdx: number, uri: string) {
    this.kind = kind
    this.presetIdx = presetIdx
    this.uri = uri
  }
}

/**
 * 用户头像存取
 *
 * AppStorage('currentUserAvatar') 字符串格式约定：
 *   - ''                 → 默认（用首字字母 + 第 0 个预设色）
 *   - 'preset:N'         → 第 N 个预设头像（N=0..5）
 *   - 'file://...'       → 沙箱里自选的图片
 *
 * 任何使用方用 @StorageProp('currentUserAvatar') 监听。
 */
export class AvatarStore {
  static readonly KEY = 'currentUserAvatar'
  static readonly KEY_VERSION = 'currentUserAvatarVersion'
  static readonly PERSIST_KEY = 'user_avatar_value'   // PreferencesUtil 持久化预设选择

  /** 应用启动时调一次：从沙箱恢复图片 / 从 Preferences 恢复预设选择 */
  static async load(context: common.Context): Promise<void> {
    if (AppStorage.get<string>(AvatarStore.KEY)) {
      return
    }
    try {
      const version = AvatarStore.findLatestVersion(context)
      if (version > 0) {
        const path = `${context.filesDir}/user_avatar_v${version}.jpg`
        if (fileIo.accessSync(path)) {
          AppStorage.setOrCreate<string>(AvatarStore.KEY, fileUri.getUriFromPath(path))
          AppStorage.setOrCreate<number>(AvatarStore.KEY_VERSION, version)
          return
        }
      } else {
        const legacyPath = `${context.filesDir}/user_avatar.jpg`
        if (fileIo.accessSync(legacyPath)) {
          AppStorage.setOrCreate<string>(AvatarStore.KEY, fileUri.getUriFromPath(legacyPath))
          AppStorage.setOrCreate<number>(AvatarStore.KEY_VERSION, 0)
          return
        }
      }
      // 没自选图，看预设值
      const presetMarkerPath = `${context.filesDir}/${AvatarStore.PERSIST_KEY}.txt`
      if (fileIo.accessSync(presetMarkerPath)) {
        const file = fileIo.openSync(presetMarkerPath, fileIo.OpenMode.READ_ONLY)
        const buf = new ArrayBuffer(64)
        const len = fileIo.readSync(file.fd, buf)
        fileIo.closeSync(file.fd)
        const decoder = util.TextDecoder.create('utf-8')
        const value = decoder.decodeToString(new Uint8Array(buf, 0, len)).trim()
        if (value && value.startsWith('preset:')) {
          AppStorage.setOrCreate<string>(AvatarStore.KEY, value)
        }
      }
    } catch (err) {
      console.info('[AvatarStore] 未找到已保存的头像')
    }
  }

  /** 选预设头像 0-5 */
  static async setPreset(context: common.Context, idx: number): Promise<void> {
    if (idx < 0 || idx >= AVATAR_PRESETS.length) return
    const value = `preset:${idx}`
    AppStorage.setOrCreate<string>(AvatarStore.KEY, value)
    // 持久化
    try {
      const path = `${context.filesDir}/${AvatarStore.PERSIST_KEY}.txt`
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
      fileIo.writeSync(file.fd, value)
      fileIo.closeSync(file.fd)
    } catch (e) { /* ignore */ }
  }

  /** 从相册选自定义图片 */
  static async pick(context: common.Context): Promise<boolean> {
    try {
      const options = new photoAccessHelper.PhotoSelectOptions()
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      options.maxSelectNumber = 1
      const picker = new photoAccessHelper.PhotoViewPicker()
      const result = await picker.select(options)
      if (!result || !result.photoUris || result.photoUris.length === 0) {
        return false
      }

      const sourceUri = result.photoUris[0]
      const prevVersion = AppStorage.get<number>(AvatarStore.KEY_VERSION) || 0
      const newVersion = prevVersion + 1
      const dstPath = `${context.filesDir}/user_avatar_v${newVersion}.jpg`

      const srcFile = fileIo.openSync(sourceUri, fileIo.OpenMode.READ_ONLY)
      const dstFile = fileIo.openSync(dstPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
      try {
        fileIo.copyFileSync(srcFile.fd, dstFile.fd)
      } finally {
        fileIo.closeSync(srcFile.fd)
        fileIo.closeSync(dstFile.fd)
      }

      AppStorage.setOrCreate<string>(AvatarStore.KEY, fileUri.getUriFromPath(dstPath))
      AppStorage.setOrCreate<number>(AvatarStore.KEY_VERSION, newVersion)

      AvatarStore.cleanupOldVersions(context, newVersion)
      return true
    } catch (err) {
      const e = err as BusinessError
      console.error(`[AvatarStore] 选择头像失败: ${e.code} - ${e.message}`)
      return false
    }
  }

  /** 解析当前头像值，返回类型与索引 */
  static parse(value: string): AvatarParseResult {
    if (!value || value.length === 0) {
      return new AvatarParseResult('default', 0, '')
    }
    if (value.startsWith('preset:')) {
      const n = parseInt(value.substring(7), 10)
      return new AvatarParseResult('preset', isNaN(n) ? 0 : n, '')
    }
    return new AvatarParseResult('file', 0, value)
  }

  private static findLatestVersion(context: common.Context): number {
    try {
      const files = fileIo.listFileSync(context.filesDir)
      let max = 0
      files.forEach((name: string) => {
        const m = name.match(/^user_avatar_v(\d+)\.jpg$/)
        if (m) {
          const v = parseInt(m[1], 10)
          if (v > max) max = v
        }
      })
      return max
    } catch (e) {
      return 0
    }
  }

  private static cleanupOldVersions(context: common.Context, keepVersion: number): void {
    try {
      const files = fileIo.listFileSync(context.filesDir)
      files.forEach((name: string) => {
        const m = name.match(/^user_avatar_v(\d+)\.jpg$/)
        if (m && parseInt(m[1], 10) !== keepVersion) {
          try {
            fileIo.unlinkSync(`${context.filesDir}/${name}`)
          } catch (e) { /* ignore */ }
        }
        if (name === 'user_avatar.jpg') {
          try {
            fileIo.unlinkSync(`${context.filesDir}/${name}`)
          } catch (e) { /* ignore */ }
        }
      })
    } catch (e) { /* ignore */ }
  }
}

