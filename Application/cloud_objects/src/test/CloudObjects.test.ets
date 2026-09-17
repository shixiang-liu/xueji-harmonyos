import { describe, it, expect } from '@ohos/hypium'
import { IdGenerator } from '../main/ets/id-generator/IdGenerator'

export default function cloudObjectsTest() {
  describe('cloudObjectsTest', () => {
    it('exportsIdGeneratorObjectName', 0, () => {
      const idGenerator = new IdGenerator()
      expect(idGenerator.name).assertEqual('id-generator')
    })
  })
}
