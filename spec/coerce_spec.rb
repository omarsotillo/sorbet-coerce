# typed: false
require 'sorbet-coerce'
require 'sorbet-runtime'

describe T::Coerce do
  context 'when given T::Struct' do
    class ParamInfo < T::Struct
      const :name, String
      const :lvl, T.nilable(Integer)
      const :skill_ids, T::Array[Integer]
    end

    class ParamInfo2 < T::Struct
      const :a, Integer
      const :b, Integer
      const :notes, T::Array[String]
    end

    class Param < T::Struct
      const :id, Integer
      const :role, String, default: 'wizard'
      const :info, ParamInfo
      const :opt, T.nilable(ParamInfo2)
    end

    let!(:param) {
      T::Coerce[Param].new.from({
        id: 1,
        info: {
          name: 'mango',
          lvl: 100,
          skill_ids: ['123', '456'],
        },
        opt: {
          a: 1,
          b: 2,
        },
        extra_attr: 'does not matter',
      })
    }

    let!(:param2) {
      T::Coerce[Param].new.from({
        id: '2',
        info: {
          name: 'honeydew',
          lvl: '5',
          skill_ids: [],
        },
        opt: {
          a: '1',
          b: '2',
          notes: [],
        },
      })
    }

    it 'reveals the right type' do
      T.assert_type!(param, Param)
      T.assert_type!(param.id, Integer)
      T.assert_type!(param.info, ParamInfo)
      T.assert_type!(param.info.name,String)
      T.assert_type!(param.info.lvl, Integer)
      T.assert_type!(param.opt, T.nilable(ParamInfo2))
    end

    it 'coerces correctly' do
      expect(param.id).to eql 1
      expect(param.role).to eql 'wizard'
      expect(param.info.lvl).to eql 100
      expect(param.info.name).to eql 'mango'
      expect(param.info.skill_ids).to eql [123, 456]
      expect(param.opt).to be nil # missing notes

      expect(param2.id).to eql 2
      expect(param2.info.name).to eql 'honeydew'
      expect(param2.info.lvl).to eql 5
      expect(param2.info.skill_ids).to eql []
      expect(param2.opt.a).to eql 1
      expect(param2.opt.b).to eql 2
      expect(param2.opt.notes).to eql []

      expect(
        T::Coerce[T.nilable(Param)].new.from({
          id: 3,
          info: {
            # missing required name
            lvl: 2,
          },
        })
      ).to be nil
    end
  end

  context 'when the given T::Struct is invalid' do
    class Param2 < T::Struct
      const :id, Integer
      const :info, T.any(Integer, String)
    end

    it 'raises an error' do
      expect {
        T::Coerce[Param2].new.from({id: 1, info: 1})
      }.to raise_error(ArgumentError)
    end
  end

  context 'when given primitive types' do
    it 'reveals the right type' do
      T.assert_type!(T::Coerce[Integer].new.from(1), Integer)
      T.assert_type!(T::Coerce[Integer].new.from('1.0'), Integer)
      T.assert_type!(T::Coerce[T.nilable(Integer)].new.from(nil), T.nilable(Integer))
    end

    it 'coreces correctly' do
      expect{T::Coerce[Integer].new.from(nil)}.to raise_error(T::CoercionError)
      expect(T::Coerce[T.nilable(Integer)].new.from(nil) || 1).to eql 1
      expect(T::Coerce[Integer].new.from(2)).to eql 2
      expect(T::Coerce[Integer].new.from('1.0')).to eql 1

      expect(T::Coerce[T.nilable(Integer)].new.from('invalid integer string')).to be nil
      expect(T::Coerce[Float].new.from('1.0')).to eql 1.0
    end
  end

  context 'when dealing with arries' do
    it 'coreces correctly' do
      expect(T::Coerce[T::Array[Integer]].new.from(nil)).to eql []
      expect(T::Coerce[T::Array[Integer]].new.from('not an array')).to eql []
      expect(T::Coerce[T::Array[Integer]].new.from('1')).to eql [1]
      expect(T::Coerce[T::Array[Integer]].new.from(['1', '2', '3'])).to eql [1, 2, 3]
      expect(T::Coerce[T::Array[Integer]].new.from(['1', 'invalid', '3'])).to eql []
      expect(
        T::Coerce[T::Array[T.nilable(Integer)]].new.from(['1', 'invalid', '3']),
      ).to eql [1, nil, 3]
      expect(
        T::Coerce[T::Array[T::Array[Integer]]].new.from(['', '', '']),
      ).to eql [[], [], []]
      expect(
        T::Coerce[T::Array[T::Array[Integer]]].new.from([['1'], ['2'], ['3']]),
      ).to eql [[1], [2], [3]]
    end
  end
end