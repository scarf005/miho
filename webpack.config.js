const HtmlWebpackPlugin = require('html-webpack-plugin')
const path = require('path')

module.exports = {
  mode: 'none',
  mode: 'development',
  entry: './src/index.js',
  output: {
    filename: 'main.js',
    path: path.resolve(__dirname, 'dist'),
  },
  clean: {
    keep: /\.git/,
  }
  // plugins: [
  //   new HtmlWebpackPlugin()
  // ]
}
