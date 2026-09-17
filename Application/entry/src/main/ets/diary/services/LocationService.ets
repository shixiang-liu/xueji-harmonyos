import geoLocationManager from '@ohos.geoLocationManager'
import { AmapPoiService } from './AmapPoiService'
import { PreferencesUtil } from '../../common/utils/PreferencesUtil'
import { NoteItem } from '../model/NoteItem'
import { common } from '@kit.AbilityKit'

export interface LearningLocation {
  locationName: string
  locationAddress: string
  latitude: number
  longitude: number
}

interface LearningLocationAddress {
  locationName: string
  locationAddress: string
}

export class LocationService {
  /** 当前是否有后台定位任务在跑 */
  private static pendingNoteId: string | null = null

  /**
   * 后台定位：页面退出后仍继续，完成后直接写入存储
   * @param context 应用上下文（必须在页面还在时传入）
   * @param noteId 目标笔记 ID
   * @param onDone 可选回调，页面还在时可用于更新 UI
   */
  static fetchAndSaveInBackground(
    context: common.Context,
    noteId: string,
    onDone?: (location: LearningLocation) => void
  ): void {
    if (LocationService.pendingNoteId === noteId) return
    LocationService.pendingNoteId = noteId

    LocationService.getCurrentLearningLocation().then(async (location) => {
      if (!location.locationName) return
      try {
        const allNotes = await PreferencesUtil.loadNotes(context)
        const note: NoteItem | undefined = allNotes.find((n: NoteItem) => n.id === noteId)
        if (note && !note.locationName) {
          note.locationName = location.locationName
          note.locationAddress = location.locationAddress || ''
          note.latitude = location.latitude
          note.longitude = location.longitude
          await PreferencesUtil.saveNote(context, note)
          console.info(`[LocationService] 后台定位完成，已保存到笔记 ${noteId}`)
        }
      } catch (e) {
        console.warn('[LocationService] 后台保存定位失败:', e)
      }
      LocationService.pendingNoteId = null
      if (onDone) onDone(location)
    }).catch(() => {
      console.warn('[LocationService] 后台定位失败')
      LocationService.pendingNoteId = null
    })
  }

  static emptyLocation(): LearningLocation {
    return {
      locationName: '',
      locationAddress: '',
      latitude: 0,
      longitude: 0
    }
  }

  static async getCurrentLearningLocation(): Promise<LearningLocation> {
    const request: geoLocationManager.CurrentLocationRequest = {
      priority: geoLocationManager.LocationRequestPriority.ACCURACY,
      scenario: geoLocationManager.LocationRequestScenario.UNSET,
      maxAccuracy: 30,
      timeoutMs: 15000
    }
    let currentLocation: geoLocationManager.Location

    try {
      currentLocation = await geoLocationManager.getCurrentLocation(request)
    } catch (error) {
      currentLocation = geoLocationManager.getLastLocation()
    }

    const latitude = currentLocation.latitude
    const longitude = currentLocation.longitude
    console.info(`[Location] GPS ${latitude.toFixed(6)}, ${longitude.toFixed(6)}`)

    // 优先调高德 POI 检索（能拿到楼宇名）
    try {
      const amap = await AmapPoiService.lookupNearbyPoi(longitude, latitude)
      if (amap !== null && amap.formattedAddress.length > 0) {
        const finalName = amap.formattedAddress
        console.info(`[Location] 使用高德结果: name="${finalName}"`)
        return {
          locationName: finalName,
          locationAddress: amap.formattedAddress,
          latitude: latitude,
          longitude: longitude
        }
      }
      console.warn(`[Location] 高德返回空，走系统兜底`)
    } catch (e) {
      console.error(`[Location] 高德请求异常: ${(e as Error).message}`)
    }

    // 兜底：系统逆地理编码（只能到门牌号）
    const address = await LocationService.reverseGeocode(latitude, longitude)
    console.info(`[Location] 系统兜底: name="${address.locationName}"`)
    return {
      locationName: address.locationName,
      locationAddress: address.locationAddress,
      latitude: latitude,
      longitude: longitude
    }
  }

  static createManualLocation(locationName: string, locationAddress: string = ''): LearningLocation {
    return {
      locationName: locationName.trim(),
      locationAddress: locationAddress.trim(),
      latitude: 0,
      longitude: 0
    }
  }

  static displayText(location: LearningLocation): string {
    if (location.locationName.trim().length > 0) {
      return location.locationName.trim()
    }

    if (location.locationAddress.trim().length > 0) {
      return location.locationAddress.trim()
    }

    return ''
  }

  private static async reverseGeocode(latitude: number, longitude: number): Promise<LearningLocationAddress> {
    try {
      if (!geoLocationManager.isGeocoderAvailable()) {
        return LocationService.createCoordinateAddress(latitude, longitude)
      }

      const request: geoLocationManager.ReverseGeoCodeRequest = {
        latitude: latitude,
        longitude: longitude,
        locale: 'zh',
        maxItems: 1
      }
      const addresses = await geoLocationManager.getAddressesFromLocation(request)
      if (!addresses || addresses.length === 0) {
        return LocationService.createCoordinateAddress(latitude, longitude)
      }

      const address = addresses[0]
      const locationName = LocationService.pickFirstNonEmpty([
        address.roadName,
        address.premises,
        address.subLocality,
        address.locality,
        address.administrativeArea
      ])
      const locationAddress = LocationService.joinAddressParts([
        address.countryName,
        address.administrativeArea,
        address.locality,
        address.subLocality,
        address.roadName,
        address.premises
      ])

      return {
        locationName: locationName || LocationService.formatCoordinate(latitude, longitude),
        locationAddress: locationAddress || LocationService.formatCoordinate(latitude, longitude)
      }
    } catch (error) {
      return LocationService.createCoordinateAddress(latitude, longitude)
    }
  }

  private static createCoordinateAddress(latitude: number, longitude: number): LearningLocationAddress {
    const coordinate = LocationService.formatCoordinate(latitude, longitude)
    return {
      locationName: coordinate,
      locationAddress: '系统定位坐标'
    }
  }

  private static formatCoordinate(latitude: number, longitude: number): string {
    return `${latitude.toFixed(6)}, ${longitude.toFixed(6)}`
  }

  private static pickFirstNonEmpty(values: Array<string | undefined>): string {
    for (let i = 0; i < values.length; i++) {
      const value = values[i]
      if (value && value.trim().length > 0) {
        return value.trim()
      }
    }
    return ''
  }

  private static joinAddressParts(values: Array<string | undefined>): string {
    const parts: string[] = []
    for (let i = 0; i < values.length; i++) {
      const value = values[i]
      if (value && value.trim().length > 0 && parts.indexOf(value.trim()) === -1) {
        parts.push(value.trim())
      }
    }
    return parts.join('')
  }
}
