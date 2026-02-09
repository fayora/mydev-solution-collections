# Solution collection



Enable types
@description('Typed JSON content loaded at compile time')
type MyJsonType = {
  key1: string
  key2: int
}

@description('Load JSON file as a compile-time constant')
var jsonData = loadJsonContent('./data.json') as MyJsonType

output key1 string = jsonData.key1
output key2 int = jsonData.key2
