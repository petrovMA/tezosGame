<template>
  <div class="hello">
    <h1>{{ msg }}</h1>
        <h1><a href="../../static/index.html">Go to Tezos dApp!!!</a></h1>
        <h1><a href="../../static/howTo.html">How to use?</a></h1>
  </div>
</template>

<script>
export default {
  name: 'Home',
  data () {
    return {
      msg: 'Welcome to "Save Your Tezos property" project!'
    }
  }
}
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped>
h1, h2 {
  font-weight: normal;
}
ul {
  list-style-type: none;
  padding: 0;
}
li {
  display: inline-block;
  margin: 0 10px;
}
a {
  color: #42b983;
}
</style>
