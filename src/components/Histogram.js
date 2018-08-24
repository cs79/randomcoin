import React from 'react'
import { Bar } from 'react-chartjs-2'

// calculate bins for a simple histogram using Bar class
const calcHistogramBars = rates => {
    var barData = Array(10).fill(0)
    rates.forEach(function(elt) {
      // big dumb switch since I don't know how else to do this in JS
      if (elt >=50 && elt < 60) {
        barData[0] += 1
      } else if (elt >= 60 && elt < 70) {
        barData[1] += 1
      } else if (elt >= 70 && elt < 80) {
        barData[2] += 1
      } else if (elt >= 80 && elt < 90) {
        barData[3] += 1
      } else if (elt >= 90 && elt < 100) {
        barData[4] += 1
      } else if (elt >= 100 && elt < 110) {
        barData[5] += 1
      } else if (elt >= 110 && elt < 120) {
        barData[6] += 1
      } else if (elt >= 120 && elt < 130) {
        barData[7] += 1
      } else if (elt >= 130 && elt < 140) {
        barData[8] += 1
      } else if (elt >= 140) {
        barData[9] += 1
      }
    })
    return barData
  }

const Histogram = props => {
    return (
        <div className="graphic-container">
            <Bar data={{
                labels: ["50-60", "60-70", "70-80", "80-90", "90-100", "100-110", "110-120", "120-130", "130-140", "140-150"],
                datasets: [
                    {
                        data: calcHistogramBars(props.latestRates),
                        label: "Latest Transacted Rates by Bucket"
                    }
                ]
            }} />
        </div>
    )
}

export default Histogram
