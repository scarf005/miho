const path = require(`path`)
const HtmlWebpackPlugin = require(`html-webpack-plugin`)

module.exports = {
  mode: `none`,
  mode: `development`,
  entry: `./src/index.js`,
  output: {
    filename: `main.js`,
    path: path.resolve(__dirname, `dist`),
  },
  module: {
    rules: [{ test: /\.pug$/, use: 'pug-loader' }],
  },
  plugins: [
    new HtmlWebpackPlugin({
      filename: `index.html`,
      template: `src/index.pug`,
    }),
  ],
}
