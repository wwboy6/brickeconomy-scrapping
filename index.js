function sleep(duration) {
  return new Promise(resolve => setTimeout(resolve, duration));
}

async function* generator() {
  for (let i = 0; i < 10; ++i) {
    console.log(`start ${i}`)
    await sleep(100)
    console.log(`end ${i}`)
    yield i
  }
}

async function main() {
  const g = generator()
  const promises = []
  let promise
  let i = 0;
  while (!(result = g.next()).done) {
    console.log(++i, result)
    const test = await result
    console.log(i, test)
    promises.push(promise)
  }
  console.log('count', promises.length)
  await Promise.all(promises)
}

main()
