Model = require("backbone").Model
module.exports = Zoomer = Model.extend

  defaults:
    columnWidth: 15
    metaWidth: 90
    labelWidth: 100

    rowHeight: 15
    textVisible: true
    labelLength: 20
    labelFontsize: "10px"
    stepSize: 1

    boxRectHeight: 5
    boxRectWidth: 5
