// modern js not supported
// use of require is mandatory
// please don't try to refactor it into import
const path = require('path')

module.exports = {
  mode: 'development',
  entry: './src/index.js',
  output: {
    filename: 'main.js',
    path: path.resolve(__dirname, 'dist'),
    clean: {
      keep: /\.git/,
    }
  }
}
