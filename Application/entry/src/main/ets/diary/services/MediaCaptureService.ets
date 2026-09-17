import common from '@ohos.app.ability.common'
import { camera, cameraPicker } from '@kit.CameraKit'
import { fileIo, fileUri } from '@kit.CoreFileKit'

export interface CapturedMedia {
  uri: string
  type: 'image'
}

export class MediaCaptureService {
  static async capturePhoto(context: common.Context): Promise<CapturedMedia | null> {
    const pickerProfile = MediaCaptureService.createPhotoPickerProfile(context)
    const result: cameraPicker.PickerResult = await cameraPicker.pick(
      context,
      [cameraPicker.PickerMediaType.PHOTO],
      pickerProfile
    )

    if (result.resultCode !== 0 || !result.resultUri) {
      return null
    }

    return {
      uri: result.resultUri,
      type: 'image'
    }
  }

  static createCapturedImage(uri: string): CapturedMedia {
    return {
      uri: uri,
      type: 'image'
    }
  }

  private static createPhotoPickerProfile(context: common.Context): cameraPicker.PickerProfile {
    const fileName = `photo_${Date.now()}_${Math.random().toString(36).substr(2, 6)}.jpg`
    const filePath = `${context.filesDir}/${fileName}`
    fileIo.createRandomAccessFileSync(filePath, fileIo.OpenMode.CREATE)
    const uri = fileUri.getUriFromPath(filePath)
    return {
      cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK,
      saveUri: uri
    }
  }
}
