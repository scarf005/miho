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
  plugins: [
    new HtmlWebpackPlugin({
      template: `./src/index.html`
    })
  ]
  // clean: {
  //   keep: /\.git/,
  // },
}
