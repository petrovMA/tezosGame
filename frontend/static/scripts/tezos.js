function balance (keys) {
  eztz.node.setProvider('http://alphanet-node.tzscan.io');
  let account = keys.pkh;
  $('#account').html(account);
  eztz.rpc.getBalance(account).then(function (res) {
    $('#balance').html(res / 1000000)
  }).catch(function (e) {
    console.log(e)
  })
}


function play(keys, addr, tz, projectName, player) {
  eztz.node.setProvider('https://alphanet-node.tzscan.io');
  let account = keys.pkh;
  let mtz = tz * 1000000;
  console.log(addr);
  eztz.contract.send(addr, account, keys, tz, '(Left (Pair "' + projectName + '" "' + player + '"))', 35000, 300000, 0)
    .then(function (res) {
      console.log(res);
      success(res)
    })
    .catch(function (e) {
      console.log(e);
      error(e)
    })
}

function withdrawProject(keys, addr, project) {
  eztz.node.setProvider('https://alphanet-node.tzscan.io');
  let account = keys.pkh;
  eztz.contract.send(addr, account, keys, 0, '(Right (Right (Right (Left "' + project + '"))))', 70000, 600000, 200)
    .then(function (res) {
      success(res)
    })
    .catch(function (e) {
      error(e)
    })
}

function withdrawElite(keys, addr) {
  eztz.node.setProvider('https://alphanet-node.tzscan.io');
  let account = keys.pkh;
  eztz.contract.send(addr, account, keys, 0, '(Right (Right (Left Unit)))', 60000, 500000, 200)
    .then(function (res) {
      success(res)
    })
    .catch(function (e) {
      error(e)
    })
}

function watchContract(addr) {
  let dataUrl = 'https://alphanet-node.tzscan.io/chains/main/blocks/head/context/contracts/' + addr + '/storage';
  let balanceUrl = 'https://alphanet-node.tzscan.io/chains/main/blocks/head/context/contracts/' + addr + '/balance';

  httpGetContractData(dataUrl);
  httpGetContractBalance(balanceUrl)
}

function httpGetContractData(url) {
  let xmlHttp = new XMLHttpRequest();
  xmlHttp.open('GET', url, true); // false for synchronous request
  xmlHttp.onload = function setData(e) {
    let accountInfo = JSON.parse(e.currentTarget.response);
    $('#contract-elite-balance-info').text(accountInfo.args[1].args[1].args[0].int / 1000_000);
    $('#contract-elite-wallet-info').text(accountInfo.args[1].args[0].string);
    $('#contract-admin-info').text(accountInfo.args[1].args[1].args[1].args[1].args[1].string);

    let judges = accountInfo.args[1].args[1].args[1].args[0];
    for (let i = 0; i < judges.length; i++) {
      $('#contract-judges-info').append('<br><strong>' + judges[i].string + '</strong>');
    }

    let projects = accountInfo.args[1].args[1].args[1].args[1].args[0];
    for (let i = 0; i < projects.length; i++) {
      $('#contract-projects-info').append('<div class="alert alert-primary">' +
          'Name: <strong>' + projects[i].args[0].string + '</strong>' +
          '<br>Balance: <strong>' + projects[i].args[1].args[0].int / 1000_000 + ' ꜩ</strong>' +
          '<br>Wallet: <strong>' + projects[i].args[1].args[1].string + '</strong></div>');
    }

    let games = accountInfo.args[0];
    for (let i = 0; i < games.length; i++) {
      let votes = games[i].args[1].args[1].args[1];
      let votesSum = 0;
      let votesHtml = '';

      for (let j = 0; j < votes.length; j++) {
        votesSum += votes[j].args[1].int;
        votesHtml += 'Judge: ' + votes[j].args[0].string + '<br>Vote: ' + votes[j].args[1].int + '<br>';
      }

      let style = 'warning';
      if(votes > 0)
        style = 'success';
      else if(votes < 0)
        style = 'danger';

      $('#contract-games-info').append('<div class="alert alert-' + style + '">' +
        'Player: <strong>' + games[i].args[0].string + '</strong>' +
          '<br>Name: <strong>' + games[i].args[1].args[0].string + '</strong>' +
          '<br>Prize(%): <strong>' + 100 / games[i].args[1].args[1].args[0].int + '%</strong><br>' + votesHtml);
    }
  };
  xmlHttp.send(null)
}

function httpGetContractBalance(url) {
  let http = new XMLHttpRequest();
  http.open('GET', url, true); // false for synchronous request
  http.onload = function setData(e) {
    let accountInfo = JSON.parse(e.currentTarget.response);
    $('#contract-balance-info').text(accountInfo / 1000_000);
  };
  http.send(null)
}

function success(res) {
  try {
    console.log(res);
    let message = res.hash;
    $('#alerts').append('' +
      '<div class="alert alert-success" id="success-notification">' +
      '    <a href="#" class="close" data-dismiss="alert" aria-label="close">&times;</a>' +
      '    <strong>Success!</strong>  Transaction: ' + message +
      '</div>')
  } catch {
    $('#alerts').append('' +
      '<div class="alert alert-info" id="error-notification">\n' +
      '    <a href="#" class="close" data-dismiss="alert" aria-label="close">&times;</a>\n' +
      '    <strong>Info!</strong>  Can\'t find sended transaction.' +
      '</div>')
  }
}

function error(e) {
  console.log(e);
  try {
    let message = e.errors[1].with.args[0].string;
    console.log(e);
    $('#alerts').append('' +
      '<div class="alert alert-warning" id="warning-notification">' +
      '    <a href="#" class="close" data-dismiss="alert" aria-label="close">&times;</a>' +
      '    <strong>Warning!</strong>' + '  ' + message +
      '</div>')
  } catch {
    $('#alerts').append('' +
      '<div class="alert alert-danger" id="error-notification">\n' +
      '    <a href="#" class="close" data-dismiss="alert" aria-label="close">&times;</a>\n' +
      '    <strong>Error!</strong>  Can\'t send transaction.' +
      '</div>')
  }
}

function getKeysByPhrase(mnem, pass) {
  return eztz.crypto.generateKeys(mnem, pass)
}

function getKeysByKey(pKey) {
  return eztz.crypto.extractKeys(pKey)
}

function deploy(keys) {
  eztz.rpc.originate(keys, 0, contract, 'Unit', false, false, false, 5000, 100000, 500).then(console.log)
}
