public protocol ClientIden {

  // In Swift < 2.0 we can't make this `Equatable` yet,
  // as that would prevent us from being able to use `ClientIden`
  // as a generic.
  //
  // The practical implications of this means that `isIdenticalTo`
  // needs to check the type of the other object by means of a safe
  // type-cast.
  func isIdenticalTo(other: ClientIden) -> Bool

}

func ==(left: ClientIden, right: ClientIden) -> Bool {
  return left.isIdenticalTo(right)
}
