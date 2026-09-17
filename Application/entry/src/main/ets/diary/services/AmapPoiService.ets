import http from '@ohos.net.http'

/**
 * 高德 POI 服务
 * 调用高德 Web 服务 API：https://restapi.amap.com/v3/geocode/regeo
 *
 * 用 extensions=all 让接口返回最近的 POI（教学楼、图书馆等楼宇名）。
 * 校园场景比系统逆地理编码（只到门牌号）精确得多。
 *
 * 重要：鸿蒙 geoLocationManager 返回 WGS-84 坐标，高德用 GCJ-02（火星坐标系），
 * 中国大陆两者有几百米偏移，所以请求前必须先做坐标转换。
 */

const AMAP_KEY = '' // 从本地配置注入，勿提交真实 Key；为空时地点解析降级为仅坐标

interface AmapRegeoPoi {
  id?: string
  name?: string
  type?: string
  distance?: string
  address?: string
}

interface AmapRegeoResponse {
  status?: string
  info?: string
  regeocode?: AmapRegeocodeBody
}

interface AmapRegeocodeBody {
  formatted_address?: string
  pois?: AmapRegeoPoi[]
  addressComponent?: AmapAddressComponent
}

interface AmapAddressComponent {
  province?: string
  city?: string
  district?: string
  township?: string
  building?: AmapBuilding
}

interface AmapBuilding {
  name?: string | string[]
  type?: string | string[]
}

export interface AmapPoiResult {
  /** 最贴近的楼宇/POI 名称，如"格物楼" */
  poiName: string
  /** 完整结构化地址 */
  formattedAddress: string
}

/**
 * WGS-84 → GCJ-02 坐标转换（公开算法）
 * 仅在中国大陆境内偏移；境外原样返回。
 */
class GcjPoint {
  lat: number = 0
  lng: number = 0
  constructor(lat: number, lng: number) {
    this.lat = lat
    this.lng = lng
  }
}

class CoordTransform {
  private static readonly PI = 3.14159265358979324
  private static readonly A = 6378245.0
  private static readonly EE = 0.00669342162296594323

  static wgs84ToGcj02(lat: number, lng: number): GcjPoint {
    if (!CoordTransform.inChina(lng, lat)) {
      return new GcjPoint(lat, lng)
    }
    let dLat = CoordTransform.transformLat(lng - 105.0, lat - 35.0)
    let dLng = CoordTransform.transformLng(lng - 105.0, lat - 35.0)
    const radLat = lat / 180.0 * CoordTransform.PI
    let magic = Math.sin(radLat)
    magic = 1 - CoordTransform.EE * magic * magic
    const sqrtMagic = Math.sqrt(magic)
    dLat = (dLat * 180.0) / ((CoordTransform.A * (1 - CoordTransform.EE)) / (magic * sqrtMagic) * CoordTransform.PI)
    dLng = (dLng * 180.0) / (CoordTransform.A / sqrtMagic * Math.cos(radLat) * CoordTransform.PI)
    return new GcjPoint(lat + dLat, lng + dLng)
  }

  private static inChina(lng: number, lat: number): boolean {
    return lng >= 72.004 && lng <= 137.8347 && lat >= 0.8293 && lat <= 55.8271
  }

  private static transformLat(x: number, y: number): number {
    let ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * Math.sqrt(Math.abs(x))
    ret += (20.0 * Math.sin(6.0 * x * CoordTransform.PI) + 20.0 * Math.sin(2.0 * x * CoordTransform.PI)) * 2.0 / 3.0
    ret += (20.0 * Math.sin(y * CoordTransform.PI) + 40.0 * Math.sin(y / 3.0 * CoordTransform.PI)) * 2.0 / 3.0
    ret += (160.0 * Math.sin(y / 12.0 * CoordTransform.PI) + 320.0 * Math.sin(y * CoordTransform.PI / 30.0)) * 2.0 / 3.0
    return ret
  }

  private static transformLng(x: number, y: number): number {
    let ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * Math.sqrt(Math.abs(x))
    ret += (20.0 * Math.sin(6.0 * x * CoordTransform.PI) + 20.0 * Math.sin(2.0 * x * CoordTransform.PI)) * 2.0 / 3.0
    ret += (20.0 * Math.sin(x * CoordTransform.PI) + 40.0 * Math.sin(x / 3.0 * CoordTransform.PI)) * 2.0 / 3.0
    ret += (150.0 * Math.sin(x / 12.0 * CoordTransform.PI) + 300.0 * Math.sin(x / 30.0 * CoordTransform.PI)) * 2.0 / 3.0
    return ret
  }
}

export class AmapPoiService {
  /**
   * 用经纬度反查最近的 POI 名称（楼宇优先）。
   * 失败返回 null，调用方应有兜底。
   *
   * @param longitude 高德要求经度在前（WGS-84，由系统 GPS 提供）
   * @param latitude （WGS-84）
   */
  static async lookupNearbyPoi(longitude: number, latitude: number): Promise<AmapPoiResult | null> {
    if (!AMAP_KEY || AMAP_KEY.length === 0) {
      console.warn('[AmapPoi] 未配置 API Key')
      return null
    }

    // 关键：把 WGS-84 转成 GCJ-02 才能跟高德 POI 库对齐，否则中国大陆有几百米偏移
    const gcj = CoordTransform.wgs84ToGcj02(latitude, longitude)
    console.info(`[AmapPoi] 坐标转换 WGS84(${latitude.toFixed(6)},${longitude.toFixed(6)}) → GCJ02(${gcj.lat.toFixed(6)},${gcj.lng.toFixed(6)})`)

    const httpRequest = http.createHttp()
    try {
      const url = `https://restapi.amap.com/v3/geocode/regeo` +
        `?key=${AMAP_KEY}` +
        `&location=${gcj.lng.toFixed(6)},${gcj.lat.toFixed(6)}` +
        `&extensions=all` +
        `&radius=500` +
        `&output=json`

      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 6000,
        readTimeout: 6000,
        header: { 'Content-Type': 'application/json' }
      })

      if (response.responseCode !== 200) {
        console.error(`[AmapPoi] HTTP ${response.responseCode}`)
        return null
      }

      const raw = response.result as string
      const data = JSON.parse(raw) as AmapRegeoResponse

      if (data.status !== '1' || !data.regeocode) {
        // 鉴权失败 / appId 未绑定 / 配额耗尽 等都会到这里
        console.error(`[AmapPoi] 接口失败 status=${data.status} info=${data.info}`)
        console.error(`[AmapPoi] 完整响应: ${raw.substring(0, 500)}`)
        return null
      }

      const regeo = data.regeocode
      const formatted = regeo.formatted_address || ''
      const buildingName = AmapPoiService.extractBuildingName(regeo.addressComponent)
      const pois = regeo.pois || []

      console.info(`[AmapPoi] 命中: building="${buildingName}" pois=${pois.length} formatted="${formatted}"`)

      // 优先级：building.name > 校园楼宇/图书馆/实验室等强 POI > 最近 POI
      if (buildingName.length > 0) {
        return { poiName: buildingName, formattedAddress: formatted }
      }

      const top = AmapPoiService.pickBestPoi(pois)
      if (top && top.name && top.name.length > 0) {
        console.info(`[AmapPoi] 选中 POI: ${top.name} (${top.distance}m, ${top.type})`)
        return { poiName: top.name!, formattedAddress: formatted }
      }

      // 没有 POI 时返回行政地址
      if (formatted.length > 0) {
        console.warn(`[AmapPoi] 无 POI 命中，返回行政地址`)
        return { poiName: '', formattedAddress: formatted }
      }

      return null
    } catch (e) {
      console.error(`[AmapPoi] 请求异常: ${(e as Error).message}`)
      return null
    } finally {
      httpRequest.destroy()
    }
  }

  private static extractBuildingName(component: AmapAddressComponent | undefined): string {
    if (!component || !component.building) {
      return ''
    }
    const name = component.building.name
    if (typeof name === 'string') {
      return name.trim()
    }
    if (Array.isArray(name) && name.length > 0) {
      return String(name[0]).trim()
    }
    return ''
  }

  private static pickBestPoi(pois: AmapRegeoPoi[]): AmapRegeoPoi | null {
    if (!pois || pois.length === 0) {
      return null
    }
    let bestPoi: AmapRegeoPoi | null = null
    let bestScore = -9999
    pois.forEach((poi: AmapRegeoPoi) => {
      const name = poi.name || ''
      if (name.length === 0) {
        return
      }
      const score = AmapPoiService.scorePoi(poi)
      if (score > bestScore) {
        bestScore = score
        bestPoi = poi
      }
    })
    return bestPoi
  }

  private static scorePoi(poi: AmapRegeoPoi): number {
    const name = poi.name || ''
    const type = poi.type || ''
    const distance = Number(poi.distance || '999')
    let score = 0

    if (/[楼馆舍堂院中心室厅]/.test(name)) {
      score += 120
    }
    if (/(教学|实验|实训|图书|资料|学院|研究|科研|机房|教室|自习|综合|行政|办公)/.test(name + type)) {
      score += 80
    }
    if (/(学校|高等院校|科教文化|图书馆|科研机构)/.test(type)) {
      score += 60
    }
    if (/(门|路|桥|停车场|公交|地铁|广场|小区|住宅|公司|商铺|餐饮)/.test(name + type)) {
      score -= 60
    }
    score -= Math.min(distance, 500) / 10
    return score
  }
}
