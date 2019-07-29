type storage = {
  last_ping:timestamp;
  delay:int;

  owner:address;
  property_recipient:key_hash;
}

let%init storage
    (recipient: key_hash)
    (delay: int)
    (timeType: string)
    (owner: address) : storage = {
  property_recipient= recipient;
  delay = if timeType = "year" then delay*365*24*60*60
    else if timeType = "month" then delay*30*24*60*60
    else if timeType = "day" then delay*24*60*60
    else if timeType = "hour" then delay*60*60
    else if timeType = "minute" then delay*60
    else Current.failwith ("Unsupported time type. Please select 'year', 'month', 'day', 'hour' or 'minute'.", timeType);
  last_ping = Current.time();
  owner = owner
}

let%entry updateMaxDelay ((delay: int), (timeType: string)) storage =
  check_sender storage.owner;
  if timeType = "year" then ([], storage.delay <- delay*365*24*60*60)
  else if timeType = "month" then ([], storage.delay <- delay*30*24*60*60)
  else if timeType = "day" then ([], storage.delay <- delay*24*60*60)
  else if timeType = "hour" then ([], storage.delay <- delay*60*60)
  else if timeType = "minute" then ([], storage.delay <- delay*60)
  else Current.failwith ("Unsupported time type. Please select 'year', 'month', 'day', 'hour' or 'minute'.", timeType)

let%entry ping () storage =
  check_sender storage.owner;
  ([], storage.last_ping <- Current.time())

let%entry withdraw ((dest:key_hash), (amount: tez)) storage =
  check_sender storage.owner;
  ([Account.transfer ~dest:dest ~amount:amount], storage)

let%entry receiveProperty () storage =
  check_sender(Contract.address (Account.default storage.property_recipient));
  if (storage.last_ping + storage.delay) < Current.time()
  then ([Account.transfer ~dest:storage.property_recipient ~amount:(Current.balance())], storage)
  else Current.failwith ("Too early ", Current.time())

let%entry setRecipient (recipient: key_hash) storage =
  check_sender storage.owner;
  ([], storage.property_recipient <- recipient)

let%entry changeOwner (new_owner: address) storage =
  check_sender storage.owner;
  ([], storage.owner <- new_owner)

let check_sender owner =
  if owner <> Current.sender()
  then Current.failwith ("Not allowed operation for this address.", Current.sender())
