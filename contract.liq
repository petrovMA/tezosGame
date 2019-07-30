type game = {
  project: string; (* this is project name *)
  rate_reward: nat; (* reward ratio *)
  votes: (address, int) map; (* votes of judges *)
}

type proj_info = {
  deposit: tez; (* sum fees (4% of reward, for every win user with this project) *)
  wallet: key_hash (* wallet which receive project fees *)
}

type storage = {
  games : (key_hash, game) map; (* MAP (KEY_HASH - player wallet, GAME - game data) *)
  elite_wallet: key_hash; (* wallet which receive Elite fees *)
  elite_fees: tez; (* sum fees (4% of reward, for every win user) *)
  judges: address set; (* SET - judges, wallets who can vote for project (now it's oracles generate random 
votes) *)
  projects: (string, proj_info) map; (* SET - judges, wallets who can vote for project (now it's oracles 
generate random votes) *)
  admin: address; (* admin can change projects and judges *)
}


let%init storage (* deploy contract method *)
    (elite_wallet : key_hash)
    (judges: address set)
    (admin: address)
    (projects: (string, key_hash) map) = {
  games = Map; (* init games (empty map) *)
  elite_wallet;
  judges;
  projects = Map.map (fun (_, w) -> {deposit = 0tz; wallet = w}) projects; (* init projects (every project 
starts with fees ( 0tz )) *)
  admin = admin;
  elite_fees = 0tz; (* init Elite fees ( 0tz ) *)
}


let%entry play ((proj_name: string), (player: key_hash)) storage = (* play game *)
  match Map.find proj_name storage.projects with (* search project with received 'proj_name' *)
  | None -> failwith ("Project with this name doesn't exist.", proj_name) (* if project not found: Fail *)
  | Some _ -> match Map.find player storage.games with (* if project found: search game with received 
'player' *)
    | Some _ -> failwith ("This address is already playing", player) (* if game found: Fail *)
    | None -> let dcn = { (* if game with 'player' not found: Creating new Game! *)
        project = proj_name; (* set received 'proj_name' for new game *)
        rate_reward = check_amount (Current.amount()); (* calc reward rate (using 'check_amount' method) 
*)
        votes = Map
      } in ([], storage.games <- Map.add player dcn storage.games) (* save created game into contract 
storage *)

(* judges(oracles) calls this method *)
let%entry vote ((player: key_hash), (points: int)) storage = (* vote for game, 'points' - count of votes 
*)
  let judge = Current.sender() in
  if not (Set.mem judge storage.judges) (* check: 'Is judge calls this method?' *)
  then failwith ("Access denied!!!")
  else if points < -3 || points > 3 (* chect vote *)
  then failwith ("Invalid 'points' value. (expected -3..3)")
  else match Map.find player storage.games with (* search game with 'player' *)
    | None -> failwith ("This address isn't playing.")
    | Some game -> match Map.find (Current.sender()) game.votes with

        (* if judge made vote *)
      | Some _ -> if Set.size storage.judges > Map.size game.votes (* check that all othet judges made 
votes *)
          then failwith ("You already vote for this project! (You have to wait all judges)")
          else
          ()
            let votes_sum = Map.fold (fun ((_, v), acc) -> acc + v) game.votes 0 in
            if votes_sum > 0 (* won *)
            then (* won *)
              let (reward, storage) = calc_reward storage game player in
              ([send reward player], storage)
            else (* lose *)
              ([], storage.games <- Map.remove player storage.games)

        (* if judge did not vote *)
      | None -> if Set.size storage.judges > Map.size game.votes + 1p (* check: 'Is it not last voting 
judge?' *)
          then ([], storage.games <- Map.update player (* if judge not last: just adding new vote *)
                    (Some {
                        project = game.project;
                        rate_reward = game.rate_reward;
                        votes = Map.add judge points game.votes
                      })
                    storage.games)
          else (* if judge last: adding new vote and finish the game *)
            let votes_sum = Map.fold (fun ((_, v), acc) -> acc + v) game.votes 0 in

            if votes_sum + points > 0 (* won *)
            then (* won *)
              let (reward, storage) = calc_reward storage game player in (* remove game; calc fees and 
send reward to player *)
              ([send reward player], storage) (* send reward to player and update storage *)

            else (* lose *)
              ([], storage.games <- Map.remove player storage.games) (* just remove game *)


let%entry withdraw_elite_fees () storage =
  if ((Current.sender()) = (Contract.address (Account.default storage.elite_wallet)))
  then ([send storage.elite_fees storage.elite_wallet], storage.elite_fees <- 0tz)
  else failwith ("Access to elite_wallet denied!!!")


let%entry withdraw_project_fees (proj_name: string) storage =
  match Map.find proj_name storage.projects with
  | None -> failwith ("Project with this name doesn't exist.", proj_name)
  | Some proj_info ->
      if ((Current.sender()) = (Contract.address (Account.default proj_info.wallet)))
      then ([send proj_info.deposit proj_info.wallet], storage.projects <- Map.update proj_name
                (Some {
                    deposit = 0tz;
                    wallet = proj_info.wallet
                  })
                storage.projects)
      else failwith ("Access to elite_wallet denied!!!")


let%entry change_admin (new_admin: address) storage =
  if Current.sender() = storage.admin
  then ([], storage.admin <- new_admin)
  else failwith("Access to 'change_admin' function is denied!!!")


let%entry change_judges (judges: address set) storage =
  if Current.sender() = storage.admin
  then ([], storage.judges <- judges)
  else failwith("Access to 'change_judges' function is denied!!!")


let%entry change_projects (new_projects: (string, key_hash) map) storage =
  if Current.sender() = storage.admin
  then ([], storage.projects <- Map.map
            (fun (_, w) -> {deposit = 0tz; wallet = w}) new_projects)
  else failwith("Access to 'change_projects' function denied!!!")


let calc_reward storage game player =
  let (won_amount, _) = match(reward_pool / game.rate_reward) with (* calc reward (by revard ratio) *)
    | Some tz -> tz
    | None -> failwith("division by 0 impossible") in
  let (fee, _) = match(won_amount / 25p) with (* calc fee (4% Elite Tezos) and (4% organisation chosen by 
the player) *)
    | Some tz -> tz
    | None -> failwith("division by 0 impossible") in
  let reward = won_amount - fee - fee in (* calc netto reward (without fee) *)

  match Map.find game.project storage.projects with
  | None -> failwith ("Project with this name not fount in 'projects' map.", game.project)
  | Some proj_info ->
      let storage = storage.projects <- Map.update game.project
            (Some {
                deposit = proj_info.deposit + fee; (* updating project fees (adding fees from this game) 
*)
                wallet = proj_info.wallet
              })
            storage.projects in
      let storage = storage.games <- Map.remove player storage.games in (* removing this game from storage 
*)
      let storage = storage.elite_fees <- storage.elite_fees + fee in (* updating Elite fees (adding fees 
from this game) *)
      (reward, storage) (* won *)


let check_amount xtz =
  if xtz = 0.1tz
  then 40p (* if user send 0.1tz user has 40p ratio: 'percent of reward' = 'Contract.balance' / 40; (2.5% 
of Contract.balance) *)
  else if xtz = 0.5tz
  then 8p (* if user send 0.5tz user has 8p ratio: 'percent of reward' = 'Contract.balance' / 8; (12.5% of 
Contract.balance) *)
  else if xtz = 1tz
  then 4p (* if user send 1tz user has 4p ratio: 'percent of reward' = 'Contract.balance' / 4; (25% of 
Contract.balance) *)
  else if xtz = 2tz
  then 2p (* if user send 2tz user has 2p ratio: 'percent of reward' = 'Contract.balance' / 2; (50% of 
Contract.balance) *)
  else failwith ("xtz amount is not correct, (expected 0.1, 0.5, 1, 2", Current.sender())


let send amount dest =
  Account.transfer ~dest:dest ~amount:amount

