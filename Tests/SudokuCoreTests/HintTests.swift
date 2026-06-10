//
//  HintFinderPairsTests.swift
//  SudokuCore
//
//  Created by Claude on 01/03/2025.
//

import Testing

@testable import SudokuCore

struct HintTests {

    // MARK: - Enhanced Test Cases with Expected Results

    static let testGrids: [(HintTechnique, [String])] = [
        (
            .nakedSingle,
            [
                "000000000000000000000000000000000000000000283000000154000000000000000070000000090",
                "000300000000000000000400000000000000000000000000000000000000000000897000000561000",
                "000000100000000400000000000000000000000000000000000000000000000000000000896732000",
                "200000000700000000900000000600000000300000000800000000000000000000000000000014000",
                "000000000000000700000000200000000000000000491000000385000000000000000000000000000",
                "000000000000682000000395000000000000000100000000400000000000000000000000000000000",
                "000000000000000000000000000000035000092076000000041000000000000000000000000000000",
                "000000000000000000000000000000000000000000000000000000015000000036000720084000000",
                "000000000000000000000000000951000000000000000647000000300000000800000000000000000",
                "000000000000000000000000000000000000070000000090000000000000000813000000526000000",
            ]
        ),
        (
            .nakedPair,
            [
                "SCv7_32_f2e5qjqh1q1i035t1ffpld059fonfeu19pg24c94oo7nbuuomatqva49714e3fenq8v3spkoafvkhrr8r989i8dts9q4ugqq2v9hks2139h0017hiogg0c30e0g1042o6lkc0di1uet3op4qheof2lhfgm72aqu0gh0qmjb5jp5porrh3hntrl57npdm67k4ipligdmq3ihagi5opjkp1jgn2t56f3odbat51sik2d98r0ceahonglobtt6fun5oi6ugvvgdsomt85c9bjeem57jvk0ov8i9u4",
                "SCv7_32_f2e6qjudh81j223uiue2m627hnkravc3fm1c5111a1tehnr1iuv7mdejdpclh366tt3kovmiebnf6lvvdpklmdr9t7rndmnnklfiuqcrhbh8926468cr3lkii44r2e67gpaq4loi5f44slf7r68uag35khrtj404hdfooqcjdqbndnllsdonee6dfkv5ompc89091j2uhcd4o3340rs6vb1m1h9ngsao1f2gielvfl0v37u9444p3ptf9vqjru49lbg9u04h2321g9gt4cls0lf4qslh8fm2dfmo1qfh0jqtcik8",
                "SCv7_32_f2e4qjiblo13235r9fbk8skj6pmthsjeu1780d6ll0965gbf07hesbrtoc08ma5mscs7j17pqijtuvjfc5lpmc7nbctvtt5pbv7626pii000gk04hhidamblbqp6n9muadoonh0a6drvretb50p2p0edqt98c0ipc6v14dn1f9naen9r3hrfnoukkvuqb3a341backgig4q32hbjgp0kh586i0or41c3589j7pao3njjghg5lv8gg6lls1anrrea3ag7a5an1vtkjve4hj9q0a2ba2a8vjlpfpqnu89ebilbs7s8ib1f63qgg95ak",
                "SCv7_32_f2e6ajibdp1i235s1fllg6gc30ttnt067l0q91sui2h2p4lkhd2bquudddfjt2g0fdj6potpgnst99uffpmm2qsr63ruutnst1prv7636oic102ss20g39ulcdr0l3h9lcbi2qll1jj4b2c99l8lib9ftm40jimggjhf66b12evctrdkde3s6rjvjjtb9ftkm4428iisih0d3u0v1mm59ckgc3iltcs1rg9lb213h6loc9cn5aa9ha982ef0ssvujfropdsjene5eb9t6udbm67b1blv4j7ehrbduhsmgte3291n35v7s0a1n96ag",
                "SCv7_32_f2e5qja1do13237s9f7486hrh5hn718vu01a93ami480f81tg3tfeui3k601q9uef0u762vjl57rmvjdc5mqmc7nttrdptlpbv7627ak5goq38g0amp5lak0d5gi20so5ap00kic846eusniqohlek1h333cv8oi9ig625duprmr8qc7odj7v77qmivr9h88u4vr6fheu725msiupo3mccnadvtkj9629s7abuqs4a4s991ftci8hl8l8h3grlj3dq5pfs2tqp8skbmbsdgorsn6t0sc5jpfq42kggg",
                "SCv7_32_f2e7qji1do1j227shf7r2d06hggtft07fl0q9damiqh1p4lkgtbfquvhdrd463ol3bo0o37o6emrfcdshq7pt3ju93lnhruniuoothpt3k9g80518jj00n70jdj6hsb2aigh4ggg6po0b91kul54r35le368a9qojdnan7get7mtsrt7fqsppjmnckmeehsvgus54hhe9rclkg75p680b6dbcr94je6a0oh8rdk629hthcifhddid5j79ejctd77t7bdqc23tnbuifpat5f5nv300bvs9dhalqsvr5crskb3mp2nqbbjfm689eqg",
                "SCv7_32_f2e7aji1d81j237shf7h3334b6r74jbvq0bg9lhcgq8474nmq39bulrb88482u1sb1hnid7u9nlmab4vsejqffffq8tbtuvpceme6tidvc2e3qgd61i66k8789cit25550mcrf3pa75hao0jdtare7m20e3l9jqj3ed891l6bntbltmbk6fkt1v3f4csnsemmsg6r1072ha2ojhmq0pp8rbildcvavjbogin9ln0ehii7f45q5llfpomkmc20ukfmmcckct7taptni0rh5hh56o5hu7qlh7b539dufpavt4gm",
                "SCv7_32_f2e5r3idd81j2345tvh7a33fcjlsfmd66vk0i0j30p1sg8i9ndkejn9brc9ghce0iaf3sfvb6tmbfdjumqfhl3n522rfcndf3tmmn3rr70328hb1032iggttsa67256uci0p55v00g0q9q420ir2a2olemoo05f611or5vhc3j1dffeu9rqn4ectltllnjsfr8vh52fg42gp2ba7aa52ijdpgv7cj0lomef3lrhq14h9m8paifk4c4ildi0bpp397on3dpt6isnth3adso4fm2n3rq8ve67iecanmjbo6pef4s36inofe3pmhh5kc",
            ]
        ),
        (
            .nakedTriple,
            [
                "SCv7_32_f2e9ajabd91j235shfbh3q37b773dfa19s87hpj111ci8q8n5msnn9fnj92pfld086p6dhmvcmusrpbtfq6n5r47mb7cusbtjflnpn6bm5g5chuk4339kmsg94m5nke6gaojn6jnl66pbk4gr2itfjik8mupiivdpmabg76aotutojn3e8sprbubbj78v48vi4p90838ck85fo7ag306og58658kqlibsqrbqt452rh1shll7jhds2cb702euo8f1dkr912m1idafee93pmel8bo4ks44pfv7ljsg7nm2scvdojvk4u7u013796qe",
                "SCv7_32_f2e4qk291q1j037s9f749cids8i5pmovug2kgh182bh01d47arunmotna0a6nf6cf18lspisp9o2njrcnba9hc9su9u2qoupar9hi9k724g8001pc000p7140lgi83hll4722icd88dq3b9hau8o6i4lu265bbqdkooved9fisu4r5ru3r5d0rqp2q0tr7o3tcuti0stmef7dcjlk8g137fkc14grqasacuqngt3sctl685h32e9t2glq34ht30q9a0nvrd8ujvhsj34flg9innv8n7taisokdsnu06aal53a",
                "SCv7_32_f2e8qjmbdo13237siuedfkmoe4e8eavtgdv03ki6ld48g0ug3p0foutjrc2rddrq4j5ou6brtpgjldvhmfemlm4l456eresu7rdd9bknm05g04kam0aocgdg0hliss0m5css389hndc2l75s513p67411hrenv1ete65v79i223f0td9stujq7nngv9thhm3mn78v8hbm4l8j0q0c95dgg4anmj9p16oji953jrtk5nqt0nu8bq9jvk3cjuo9ju5soj4embripqm0aq5neaoormqiril7ddo9c91sfplj157s",
                "SCv7_32_f2e6ajq1d81j237shf7j3315b6b76jbvq0bg9lhcgq8474nmq29buluu9mt83m4c0pkq94ft3fj4n7puvd7gnutq1dpvurn7hsvffmpltg1j490pe40ig0r2p59o1d8eo65qc5ebp713cm2a4ak814e8aqkmcm8ke38r02qvqtr3jd6jt5o3ojrt7bfdkm4khd3c8dbe6uoitg23ffbmjgbvlqrcrqematg52hcs4lb2bht8dlf9i41ln6vkil6ohffslvkv275n6koih9edfdph1l44olcudrctrf9nvd3d4ce31sktpvo0rbtksmg",
                "SCv7_32_f2e6ajpr1r13035t9fj4dcgtsvhqss039p8aik8ll7l01181ojen2i2r0picbsfrr1olsplqirol57mpuj99ja9su9p2skqpduj3egas897p26c0gag6c04e1p0250aj2p0cjq3bk54gg6dahj19083p10n8lsla4pmgbkspvcmlujrpjp7s6ckme5c76v88thvrhh4m64e9hgciah43sqblr0u5jmat7qrckk8j0bb9n5a9p5ta37q8haan73jc8eatq8pm4dl067ljh7l1pvfego7bf5mvmmo9r3akjvn1hmds7u5n8j04",
                "SCv7_32_f2e8b3ibd81j2346tvhfa67km8m6b6uuk0jhg61j3232p4lkhebdofbi88f78kvvipvun4scvidtcoqv7rtkuiprjv9dlfurs6hqvvbs9atg802k04utokc05c8lcpoopf0gl1lb051j9h8l2li1gg1l2tiheaoqhu8am2ii657l7uhqmnhrsrerfov2ovcpptmgookghg8kacs4n38d7i9cvceru2nf3a60jciocqqoo8g1u78hf1142fc2r4r10nqni1k8bsvtlrtcar5159aro8tfdnspvsk5rbgv494qk",
                "SCv7_32_f2e4qji91r1i037s1fjk86kccdoavr8fva14gg8haba47dq3lfvbr1jk17366r0fccvtqv1eqeojpcmrd7jucsmfkt1pjivls9r0tk08944b18s8u2oc9ct8sk15c7sjqmmsv5865t8jvn208qjs84a1ahhh0o00nf7dqbnpnj7sncgv9t9pjhjblq1ohug1fmqi0b8ccg8ainjribb79hemu618dn73cvr97ef7hn46kfjse4lv78bgb82je8muefprc455qjl39l0ovrps4tjkcfc4lsj5nbbhmpam97l0",
                "SCv7_32_f2e7ajibd91j235shfbh3335fnm6pkorug282pougq84b4jmq69bmlrmioihc4h3p6hpjntkrv3fcebuf8tbcguqotrruvkcfkuetqcog01a0hhao1o0glmfh9j95d8meqnhposmmli6arqi5l86qomeb0nkfdn0poduj45utrundqknpfknpne6epvf8ae4k0m9ag2hpgk1m0lb3dkhcamcq62hcqcl82vcl6jhq22c45op4q2j3hrh1jq2s5mhv7mvsvokf6sp7i36iedpf64md31e7n675v3cn6pf4d16p4kuftfigiq3",
            ]
        ),
        (
            .nakedQuad,
            [
                "SCv7_32_f2e5qjib1913235s9fbgd9j9jaj6tt86jp07hpah20bvs5kaesrvb0cakh6p76b94q7j17vqmjlve5mmekaucvjbotmpvuv53jb4308830jm9u0rkls8m91l7e1so4773689go9e95b8nch4iup9dgeksag9gisg70hapgnlrh79mthodjrcfaafvd5hmhl05119j3a0r6lqh815rji9r1ek50biav620vtjb2k9ft81a8rjohieiov5pucc2ufdvsbf8qv078dgevphirsuul195lkfrbij41a95vk2lo7cu5tn1d5pm",
                "SCv7_32_f2e6ajidp913235s9fbgd4hk9l9reug39sgbpsh8h05vu5maevrivq836sr78kj6qb67pkjq3f5mjf3rrarlqmm7ldfouoothtttk9q14ie8fc4lt334q9cn98dqjf69g9svd9j87q25bic9lgidoqlh4ragf61ktn9f7njfgtvbi76eqtiippq71shg8kg3880o8r72qug3kkta08ol0oond804t3ftdkc15vgk561bl62tumqcs279ajac50q1vlritqha9sro8gk1o69ulj729d2bcv8ms10n4r69v8qikr7jvp3dh2mdnrk9bvnu05jmqjgs",
                "SCv7_32_f2e9qji9d81k237s9efirk6mb9ubavsg2scac68qhg7ts3g9vqtnm9hmj0ea74h8h512bvckv7eafbvurn53cdr5trrndmnnn5fiupar10cl28htodkr9a4agac4g74e9daalehm3312muqqaqj70596lkp7djc7gskn2bcreatr9ste3m7rngr9tb9u3mkm8c46j00g10d87vr2h220ljnf150k5lrqhmvqgrm01aag6b10v51gg81h612v14fmup1300oph86fv375gdvq6f4ud7lkft0",
                "SCv7_32_f2e7aja1do13237s9f75g6h7erh7199vt05p0diq8l11p07m03heue51gl1lamtmcsu1tu8mqp9lufnrmm2mrnc4mlvrfoq7bvtua75m058p062mu0506al0602jggfskgh3mt61j63pcqi9edici73tkkikikjmdf6m24tuprmr8qs7odn7un7qmavr9sa88k49sdefk7imfukqdci0c98j5shkj6d2a0r55dh1s1sj379c6p2d1kpu0jijfhkb777uufghfovo38jf9e4p81f327vcqcmlubjockss6lcrgfo0uitkol8",
                "SCv7_32_f2e8ajibdp1j225shfbk3ojf7fdv81ht86i6efaphap4hkhebbius1b7alql28o30f1s0tupdtpnn7qvkcefn8fcudplpnv67ofveshchq45pk92agifpv9q78l8lb40d1ap2cag6fjltd89em941kejr94dhekn8fsrh3urd5e2t9vjemdtnu9he88k5b8eqi01mggqkkpot0i76h7e9ocq60297oqrkjm1ob041mh85a9e0aho58k3osm5m0u997p98j0on7odlglb4p6l77gk7g24g52u6um28dav9nudekkmsaafovtqsnsg672n9mo0",
                "SCv7_32_f2e8aji1l913235s9fbhc9j9jaj6tt86vs2c4asfgas51vqv53fdr9h2h2dput1q4ickouoftesiufvtqr1bcrm2rbvtkqevqtvbr13dg1iqlo02410o32kfs165kj0ci1a3asomcklja4e3mkpq8pibccvhnf2rocjfonmqf7bothuts6qf9pbgdnv908duidil5oa8ka8p55u9soukkss5b7629c8gk85cel2t5cvffkeghjisp67o9p52vv4n58r30ds66ngmrrd4tbjtmlpvj3mfalc4os9gesibo0",
                "SCv7_32_f2e5b3ibdo1j2246tvh7ab7tc3090rbqgef21kio4d5l25i9r92qnn5tjrj3jujph07g9v56v7aafjvuqf93cdj9trfuru6hstv3j9rdaa5ik3224622n07ak1h81ckgd4cs98jo4l0bpajg1h1ek2216lgg6l90k9a9h3qmraiausprtnde3c6r3ujjtr9fdkso9v0ijcue7i2f9ie5qcglbpphqg7fu0igviul7gbpe59fmrc7llm651jnl564tvkidefv62r2tvlmtnvgbiear79fa3psv93ro",
                "SCv7_32_f2e5aju1dr1j027t2ufo610ocettfrgfuo2p2oi5iqh1tmjegt6vrts2qem9k48o3ro81ntgbrtv5mbvb8sdaadcvmtlqfnqrbnres0aj02feltkj9iu4ilhk0h5cj4e8uap2iu4h9m51hiq8q9sb918tj6ojc90aab311dfbetptmtmjnjsnkknv7f7o4250kq52k45hi8ba33lvj422k6mk4m2vo0g293s9qjlghoreog9glc12e7ja7t6duvjpjfjudnesaauuujlqrkb7j9f7clfu2e82qqgm8e9m6bketg48cl2ua1sjpge4ja5",
            ]
        ),
        (
            .hiddenSingle,
            [
                "000093000000005000000064000000000000000000000000000000000000000000700000000000000",
                "000900000000000700000000100000000300000000600000000400000000000000000800000000500",
                "000106000000740000000253000000000000000000000000000000000000000000008000000000000",
                "000000000000000000000300000000000000000007000000009000000004000000001000000002000",
                "000000000000000000000000000000030000000000000000000000000259000000780000000401000",
                "000000000000000000000000000903000000508000000710000000000000000000000000040000000",
                "000000000824073906000000000000000000000000000000000000000000000000000000000100000",
                "300000000000000000000209817000000000000000000000000000000000000000000000000000000",
                "000000000000000400000000000000000000000000070000000080000000060000000090000000030",
                "000000000000000000000000000000050000000000000000000000000200000000704000000908000",
            ]
        ),
        (
            .hiddenPair,
            [
                "010000004000050280004000001000000000000000000000000000000000000000000000000000000",
                "000000000000000000000000000000000000000000000000000000046000000000000000000508013",
                "000000000060000000010000000000000000000000000000000000003000000805000000002000000",
                "000000000000000000000000000009000000001000000026000000300000000400000000000000000",
                "000000000000000000000000000000000000000000000000000000000140057060000000009000000",
                "000360000000200000000500000000004000000009000000000000000000000000000000000000000",
                "000000000000000000000000000000000000000000000000000000001000000000006759030000000",
                "000090000000000000000060000000204000000100000000500000000000000000000000000000000",
            ]
        ),
        (
            .hiddenTriple,
            [
                "SCv7_32_f2e3qjq1do1i237s1fji03e6dd6atq8fva14h2qm918gsieq8elvtfdmetdh1i73347s6tuq3ppnr7qv4eevmabdudptpnv66pfsut2e02d19822d83q66e6gb5050j1k05i1lkaokj2ovt517md9835dsba8kvqf27cepesdqbumvcttfqjbv115m9e701jc8lp1aqo84ekf2p4draqgadnsqs3bvn7fgnibu5eotiaipl4dh485drv3i9r8q78cnjjjcqhr8itshkmc3asnqgimm29t2riet5i4dsbgj15jm4il0huqfh79jgmkr537kuuejgq85emp5m2k5e29vfs09gjskr6",
                "SCv7_32_f2e4qjibdo1j225thfbk20kc65i9nnl04u439lm8aaa4avkbaqunm8cj8qqoa3eftvhuvciusrp3jfq6r7tqtb7j6771usstmtlti5q4o5c1dlb9te8q790ik8tbrnj3mmmla3mc2eg3p15qc5ikv3an4kmbmslvhr5m372egvhnj6ebu4r3520ggg0k2384k5qga5c9j5e82le00b6kqibakg87g974ili08dg3q823c8i2em38kvsja0d6bhsha5eo0eq21smlnm26b2qgoj5nbbssj2qo6hgdf5s7pbj1kridjts5hdcsaedui4ma6sevvdu9p0volfd142bpunp40d8ua",
                "SCv7_32_f2e3aji1do1i237s1fjlh6g5reobj9hvt05i4baq452ji9391umv5toem0qs57hhofcbuobvmjmr7veke1f4uobfrvqvtkfmupt8cso0m81pkk60q34682lcg3dkl5mp4snhrgnja1qq2c95rq1apu0f6oq9pgmnmcv2ttbmndeeumurlqntk1upab20af294lt1p43mphcsb2ka8pcj4hmvaj2j7uckm4i0k20i4hd12717a8r4q2u58e55i8dbhehhopk7dlpb2e1mt15goound78ffcqs4j2stbeci5rb1af1eqvf9io7ofscklnvcm20asb8h09ef1nn3sigik50",
                "SCv7_32_f2e3r3qb1r130324tu93b5ksv29p8besg09i0dda48ghdv0m43n8tr82ind4tv7cu7i9b5mbj07u7mejerda8p9sv9sjv5jhnej6rgka909q4p2285ib99t14asv1bphpbon7c2mde88lmjaieqsd6gd3d49mt5vur5qt7qenfhni7nju7b7r49m81k0p9di1422k30q190qlaqc0m50dcpuls4jf458ci70ttqgidhckgk1r122sgbclat2lda155guni5d1hjga4nlvos8nmk296gvi3l3lddk9i8qdsm96263ruabv90amr4brb41vpbog6fmbpp8dqft07rm4k3j",
                "SCv7_32_f2e4qjq1do1j227shf7k26io3eprj9hvt05i5bdlm8aeb4547mqelnobeod1a2o4pg0e7rtkrvtfdnlvb8tat1tkuv7ncvfbfdvtpkpham23236jpak60qu50bok54ah6k5kvk3kl490op65vae3013rtp48ft3hdurl7eqs9rjunllnuehsa8cgm980c59j592qgq16i0gs58m3oldpb3dk71dk2ogear3j4cfbphpgoo76pok42kbfdaau2vttl937gf97ojpbhqoa2prvi3on1omr5ei0nv1su6pppt85d79ucosegekjaul22gk72jjkmv4b47kue5qddh8ko",
                "SCv7_32_f2e3b3q1do1j2225tvh7b41gc36696uuk0jogd6mp1998hcier8iktpfr2n2oc460tufv9n3q7rsvvmjq9sjn9d3furvmhpvvblpjjl9dq45h42568p9kfooa6ldv115d8s54lj6ajamj6i987e0d3lkn365hkh9fkutnouidqrsntduuvuvkqlh100o2ia0k7731v1s371he2qva6gb4gmud18loq2gkkl1g2sotakehr356u1io24k7ne08i35too5k2214krt8m9f0padek3f5t5klt3h2485vi6ectvkenm4gosijnkdvt8oh6piokioa47j9mh0dr0vq10qo29h56uvu015k59pe",
                "SCv7_32_f2e4b3qdhr130345tu93b5ks7v3ma2pnj09i0dda48ghdg6c0b2dqubm596pkl6fm6vmfpotmrtlgvu6le3u6sg8rfsendvjr33f64ceg7hp560brf52pj2h39v8gakenbh39tasb7r692p9gd0kbcot76dl6e44rt3rv7vqultbln6mm5f9tn8qkl2ohvcboaa598aa2k1496cla95jglh3a163a2n97u9qg9i3j8b0n6ioc1bna08nckju12dd4g2ma4rdd1g4b4u7kkab64dnob1rqnpd7btkpl2i30lon4tq4vesq1ufomq2l765ika7u22kmrgoa9qhs5iji3kv5tilmkqt",
                "SCv7_32_f2e4aji9ho1j227shf7k3ggocee6npg7ue14grdl5h2jip1rpgk7u7t07cd2u1c6lb1buqdtpninnvkcejm8fd6equs7tjbl7rnej65g41bc91k4gaubur19cnn9g8uv9ftg6up15v4ldi0t9nlk5j0d2n9i2fffsdr1l5ubt5u5rpjifo61vl0q091161cip0d86ugia1a05mcgl8d5dplo13cl1ak09m0kktk3uncpin6o0k59id9hf1d6jttidohl6sd813eri501h7hhplifr3ud9t4cu47vrhrasrcn8r1sipmjsm9c64v1mumnqged8im1t1f15l7kvo1rjkiitk",
            ]
        ),
        (
            .hiddenQuad,
            [
                "SCv7_32_f2e3qjmbdo1j227s2ufo711hoosdft0fv82p2tllb8ksk8a9fdkdavvfc1nmn5n5670cotuq3rtv5fjvlnktojr9rcvtfuurnrmquppqkv6a4f4uirs8nsvvlfo6tb4tr7vekmiq9igot24l76fm3n139ejv9sas3ubvatlrbjnsnfisbtlh0cbp6th5haa2omccp6cq58qlc4mhg6cj4tcfpvdepa6f9lhhuq59hpmt96394pptmohm2t32ct5gegcl3j07g861fgoblp6t80ouc5d07mgqaf6v6hg553gc6d9mu8u1qj5eq09fqb4kq453f1t0583hpggfbk2gld0o55s77dvkuc5i2i2lo0",
                "SCv7_32_f2e4qjq1do1j227shf7k20gc33jplvl05u4b9au8aaa474nmq0l7ubtcmd96q68cpg6f0mpeuuonp3kvmkefn8asorrnluooivonp533o65f7a57llhev44godir4ejm9ce6r5irqpet0q3ivei241dqc4sp9bu7f8vqrlvbt5u5nhjifqndj264020kig1ofh29ik9id26q28q2bql049niuo636qoq52b60cukdr0a2g41p9d7ajquufmljoodtug9rgegktlb6vpup1qsdekp239di9vmg3jdie9kep7dr9qgh4f2lo5mll0o5urojqd1l8m606gi8klimjjlejeatc7hf8ij08",
                "SCv7_32_f2e3r3i1do1j2225tvh7ab31dg1ssdlt857h0qdci6iih2p4tmh5briunqeh82o1js3vgdvcmuonr3kv3q7eq47mu7equ7r33u7nme06e95lk6dhe0hl4p2ik49964alj8j9878iuuhd8a0boid41c2i0qb231a3v2tffmt9bsnafsrl3fdvjkbh52pkau3lcskp2njfqp6lp4sorvp854dhimc34ht9u8vqcaihdniook2jb5klagv9vl6cb6dpabadqr0elrqrh9ojemsfh095ld0c4dakp4dup8pc6ghj8uqfahsvrfg1jpvg2bo54lkcm4ldk9iu3u876hs5598",
                "SCv7_32_f2e3ajqbdp1i245r1fli16ev61i9nnh04u4f9k0jaaa4b4jmq4l7fbo728i3pguooroeftnrr37e7dtrcctrgvfsujdtfm67ufgos3g14l1m32soi3ct8h0geqkko8l9g12421fldc2i25s1cp1lk2kqg8p7es6vhtv3vtfbulqbirb3ncubm18lak7hv4c9u12gq9b7drb11pp48r9p881s8nhqn7cljpcaj26b3ba9f0lp7tbtbl96cp41dnq4ngrfdvhds66pd1e9lou51hf7m1bbkj51ajacl8dcnicdvtnpoguaar6m6s6d99vcaeg5klmiobsgj6g3rjlhulgta5jg",
                "SCv7_32_f2e4ajqbdp1i235s1fllgcg63evmpkorug2927jq8a5b5i3fq6l7frsoquk213vhf3ue2erdmuont3lfjq7cm8bdsfaqu7r33e7nmeh6jqjr1gpae07r6dho2v064n0cbou2gdj7jmm4spejsaef3a5j1d73l977nnfktvbi76eqvqqopu7ht0pc6dimbcg5aoljatio4kj3a0qqhqrrbg680m9el7ngc8i60f5ivfai596eahr2k5qo6e6906cbtkl862gdqjf7bm97i6lp3afvmk533i0ienp1clk7ak922q8hpbvuo98am266d6qbc15h4t4bhvovo5haji6ll5fkuc5stbai6g",
                "SCv7_32_f2e4qjubdo1j227s2ufo610ocee6nug7vm14heqqb6575i7bq2lfunj0aekjdb1h6e1mffubeqdsnpvsbb5n276a6pfuntb3drpn2bu7gaskcrud1vqh84mste54oe3m08d264nubeb791s5m7jhanc1b07eauavdujvashpjmnsmn6ehsqhskk3b8cik6og0dcg9fln6o31b0u6sarmk0lcjbssc9dohnvr1q5h8p7mopqg1tn4bid4o706hk5b89nl3rtckof222rg1gjvkfp598v9fn2n4k2gn2pug7u5bqmumucaqnmlm3bip7do0oqj7qkhafusm6gscqriu36tpm2d0lci85d7svg1jqe5aeg",
                "SCv7_32_f2e5ak6bdo1j227s2ufhe29gcpoqtq8vsg5i5bdlm8aeb46nk5avtff0kjdtc3rcgqcs3sinb8nnqefkpub7ctaaddvr9sq7bvtur6jm15vge89aea7am1olj9lmch235p31lc2461374j19sce7j4dnrplc8d55veqlrtndejd1vjqbbu7be5kdcq32o1j6k252192g92g6d1121aahqtoavd3d18k3g41seg52sot7u1t812u5a6f1vvq0sh31a7qgumm2bk2kklin0vh7dfn23q786cqsbve4r9pv2nvgea56se64j6e1gieur9trmbjhb0e5mppa9nmeqbphnl5fa8r0",
                "SCv7_32_f2e4r3qddo1j2245tvh7b40o1gc6f6uuk0jogd6mp1998hfu2qmnlto24eqr31cd3ufsrsrnr5n77vcsbuhhput1djpjbbgveedouupp2q6c2i0lq6daenair5bj9nbnb5d65m2op0plkm1qc92mrffiprs0m3nle8kcvutojn3eashqbvbrj7gv4cd6ioogcp80aq8a4g30gb08674gbirc9712g3oq60hj811hktd8hr32grfpaqg9d3h6s3ek30bfatpa87pjtphdu6nilh2g5577m381rul9aa73bs6pcectmauujocu79to8triueb13vejphhfj1viuc5ps6ahgs",
            ]
        ),
        (
            .lockedCandidatesClaiming,
            [
                "103480759007530001450170080508601070041753800376008105600807534705004028004005017",
                "008400765000000401040070098060054912004910650519020840386542179900000584450089006",
                "512008347389745216060312859005407621000021593020509478200000100000276980008150702",
                "307000068856007020092608070063009847908076135570083692730804256000360789680702413",
                "000000000000000000000020000000000000000000000000000000000570000000614000000809000",
                "000000000000000000000000000000000900000478000000150000000000000000000000000000000",
                "000800000000000000000000000000046000000010000000039000000000000000000000000000000",
                "000720000000109000000460000000008000000000000000000000000000000000000000000000000",
            ]
        ),
        (
            .lockedCandidatesPointing,
            [
                "380105002120003850560820713600008031073510608841632597030986170018357000706241380",
                "048500009200941030091078406829607040010894062400002987172400090980000070630789200",
                "194082005000190082872530190049061508085240901701859000908420617410078259007910843",
                "682943517000701026170602400006075001010060700700810602061407985507108264408506173",
                "000014265604020310201603040729386154305149072410572003100400720002001030000200001",
                "000000000000000000000020000000000000000000000000000000000570000000614000000809000",
                "000000000000000000000000000000000900000478000000150000000000000000000000000000000",
                "000800000000000000000000000000046000000010000000039000000000000000000000000000000",
            ]
        ),
        (
            .xWing,
            [
                "SCv7_32_f2e7ajib1b13045t9fb0rf2c78pmjdvl0qf40q18g7hc5nq2u7n4smlbdpi21f3pnv6c6jd76bncmfdrnpltol3ev6s2mktpjheuu60qc81bk0206gp11hcu2gq338lh5ah5r6poa260hdhii858pc241cb846jfhbmm1ltotcspv1hspv1u2e4mu5ocjt93f21duhki9sll50t4s8ssghplsdrmaiku4dsvpikbc2b2lomfq1jfltlc5386uddtjnqp13ausb97tslkd3liakkfhuqsofavsl6kkm0",
                "SCv7_32_f2e7b3i1d91j2324tvh7a113b6raar6j3fq090bf7q390hcier8t5eqnrugmjeh8cf2a0dvmv0pqr5thni78v7nmnp5umu7fsubr33mr6nmh6ci4r60jga66187e6dc62inppgt0872gmm0pqo5c96t3ci4mgb6tj80dj15b6onmj5uulrun5q57qfgngnm6eaufbb98s8255mv6bn59al1dbgqm45v2bgfl183jibj5u82lssmqihjoi8qa2r6102tfer693sdf0fo3fbu2fjoej749s7sfhnk9vel9ujqgqo7f975g",
                "SCv7_32_f2e9aji11q1j037r9f7l8smja0datr07fc0h45daggs01mr1qfvbs546ohqv29c93n3mucpef6seelpilla6dj6f6jfv565nqmq0dnh1ma06k8bdmkh9g80u9oglokvk3iumml0ggjle08vbk0lc0ucl07h40h8rp43t99hihsqiqncqkqn9v1psuhdil3ssi22s41eo0d26osa1a6kbmlbj9c6vqdk5i5o3ie4m4vqhue4mqcj19htb0fou3e7jr19u1j60quafmp1ubvjegi6q",
                "SCv7_32_f2e6qjeb1o13227siuf6q0gk53qqkvv02uc6pcr9c8ufgej8vhrtjlat6n528t1q0f1irt47qpmtldc6clco9fitt9vdrujm7a36a00ku1960805202d6940j702jev3nui201g5gh5k49ebp56pem6l68j2sgnej7nme24be0vddgtatpranrdudfevcl478f5101p8ecmagkc54aogneeg50vmqarem66jopsdu2190v9h9gqcejdrdtqnsrbans8d9lut47htvh77ridu660cs7v010si97o0",
                "SCv7_32_f2e8aji11r13037r9f7kosmilhmnc79vs02khat69a4066os83u9r9gjc8rp89jdc8tutiudmsp9rihjnd0gurhehtu3r5lpli5hmn2c7rq0kc47joi4bbt4s8sg4v820j8eg8b42no53eae85038k4da1lmr5ai0jbq2etove96uotubj3f6t9aqdssqpk4tobp9r709tsdtclt8cbko4a2ktfqb1htn47lnsju8mih0seblmopmktldvfp1rnb41hfm3b93rf4m1fmvehii2eibjevm0pe4h4ja",
                "SCv7_32_f2e6b3a118132325tv9bb1evkh6h7drq0d7i0j0p1bh64hit53fdqti4i68o8nvuvdkv4s73ai3k7f8nmuqoq6vblmefetdcivcmqn9ga80i60ch0c006snar960kampk30hk0ibgocbgka0i61gj6s40qd42phh1k4mtoteeecndpbkr8esugothqbt43u1fslc9u2l2d7ql7s0p65nkni04p7h45qebmqbqmdqqfffgaaq35d0afrpkbfambtb57tdnu86trsg4vo78s10",
                "SCv7_32_f2e6qjmbh81j237riue6mk3cotonkrfvc2vq0c3112a1tuhqtj97urpimcevdc4o7292or7tgjstl9lfupes7fncobe9ttbidhprnnu27oce04c52k64rc4ok404of61mdc1f2rk868sqo8a8saes0kaeabe25bom6gs14u6m05oumtt3rlfiv1obmj3d7feeke04hbjab8aga265fl5mhuf5d7oonutig3ovmkheovt6dnp0sijaig9pftv8lenqmcnjqt3n2048iciabomrisipicc9ur71fspo6119iep5tqpm6vo3gnb1k41kiv4",
                "SCv7_32_f2e7qjibd81j235thfbm7415b6bb4jbei09g9hgcgogom97dkainfbsk9gga2k0b7vpjt4nsjmbcn64fselqf7add4cpvvbs335rgnej5o0h0d58o300cvlgg5pndmdc6ag36a985lma59h0g3n45peip2o132l91dmaa4hmq4qab3rbnvmfnene9vjnjj57be7kb14s14ok7bi50ddi1li02c3ifggpalpg3ifii2kcllglrhq27jsa1rofodn7ol87quv1nors55dnp7ohre6vvsl65v2n9svrvv4n96bg",
            ]
        ),
        (
            .xyWing,
            [
                "SCv7_32_f2e8qjab1b13045t9fb0rf2c6afrhl8rf2144go92gbvs5kaeurt2aka3eco2dtsrtedre5foer5t2irsn78rtaseqdjlln3o6mhp6bgph4k6pgdioh4i028igmim00m0go4g4p0q429j849cnb341d48r7g2q04iap69e6ejk76bfpeqeqestq33nt66qcfs3vhiijdfss8toi9jq12kdairb6u2p966qnm5rqgv21caovmdq0kujv043fb0636m4aiv4hsb8vv40jnnc1no9i7s0",
                "SCv7_32_f2e7b3ed18132344ruiuebacrcq4rf7a3fs082qrir1e5gdvgfhbn6tdl0bmao684gcrtesrhtmtldqrekdhrn6slrqr0qrj7eftphg9i08p2548195gam8j40e9aibih32h5i4iggca892mpai2b2ndr6l03lgmlepec4m91nn75am7dlepdrboj3d397nb1a10uh4ur7dq1d5qj30hfskhvba6u69uullo4vp923rilvh8m3c3euvquvo4nhn833irfbc85sj7pr13uts04eom8rk0",
                "SCv7_32_f2e6qjib1913245r9fbhdkn9ejd73apnu02c4asfgas7gvgmh9rnfunsg892cja97bktb3aj3creqkmta8bmsr77n9frfc8t1tneia5080c2kg2gqc22q68k4id9971k2p6k4g763riq0gg9t07sh0l010i9a8kq533s0rn19q3jlbfadqrtlrk76pm8vd8no71geae6rhiruf6f50v197hlu7du1ogvvpdpgkquug5h57n7mfqca7pguk366v7f178od7ovp0bcjv5no7g6stqfrp3qo",
                "SCv7_32_f2e6qjih1q13035tpev5jkjmberv5apnu0228b3417gg7k0fhlrrf021hjj6qnavvfrdl1v9or95tihtjdd2lkslbcfct99budi6k0s0a4414267s097k0i8hgff928ugdke4k0ie649s0vpl0h2rcibr90h0htb2p911lg49hiqskou9usuujudq2bbd6fj6b42eiuuo8dp2d08tvu07homd5jqpno2g52vsli5bo7vqcfo0knb6tt29qm3eq2hj4tsh61c19mmmo9o6jeed8brk5hv6v01bl6kh00",
                "SCv7_32_f2e7aji91r1i037s1fji13890q9mnuk3nog54k442jip0bk7arunm3fd4l98n187hscov7r6r75nobkfdi3d96d5rjpncaibn5fcoo04f848ias20n208gc40u4nfc8fjgh3ng4juh4imqka5322sdddisj4tb3valhjkstrshuspqpq9rdlppn9jalh3b3o9dur1kel2sm7jm0q85l1rf2oari186ibbu25bssqkmous8u0jvg1hmntqn9kblev6mae725qibj7077ds3dhk3g7ma17jf81lik4j10",
                "SCv7_32_f2e6qjmb1b13047siue0rj3eqb6sdavug5fl0q1807om1ao7olvje3sb11j0tcsfj7m3pjbspn9iifsir73pr6fj7leosueetdhfdhgj8sjhl1gg845ce04k0ch9a8jqap49qe99jmlbggng1i34d84qt9hiaq181gbsrjmsipq3r97jv4o5t9hshllql1r0vsgkk8tfhka3dc7lrfp3mteui9u5q95sal0iot8p77u8guinjhula4dadm9rf3pr0qkk363t7l4ksfn3spmhj1qfho1f6ug3148kgk0",
                "SCv7_32_f2e6qjeb1813237siuf5ri53959qvug7fq0r0p99h23lrtd0v3nqcl8f7qca8od6p762qj3j3lrvamm27ans4l1fsmsaqkpt5lghr000o2a4akg6q24adhgh4mspoj810gc49g80blgufbh6hfh8p4j64m4oi38pickmb2b12n74n69nslodhr4fccevf9uigb80c67sq44bqfs1qjl5mva2a1ti7hvn6r9t1vf8pntepbmkir2aati2ug5fqdfl5von7v4vv4bu3vg0ncmke9g",
                "SCv7_32_f2e8ajq91b1j037shf7h3i5i2ottft07fl0i09go887eisj8t7fumd1kkm3l429khi2398tr3ebj476b5mtjcdbe5jbjo7uab372flpqirg8qk1h594m4rp1f79hh10o9k8p28v15cm8jh64cgdfoigpas6en26oljbckhatscnaff3kf6dbkvgupb89vspagjocialgqvvuidog8840pgnstopt95kf835a02k1frfqgkn22kk6t4nlnnekhna4k2q9390ginrjb8bqrnkcmdlqos9peq28rk",
            ]
        ),
        (
            .yWing,
            [
                "SCv7_32_f2e7r3id1o122345tv15l4ie55mn3apnu029634pi0c1fvhd6jfdq0l3sd51ka1snqudf9srptijl527erdr8sbjn7jt7fmcslt72mp779800mu4440igi4a51e5ad89405441c458igcgmgc0ehhr8eghh05mo351405drhmt5jtrviu6s1mjqjj736nbi1s0vhbm27c4vg1u28mj5e90vmdvs56sd0mqvltn958jq9hc49pi6j1doe4pf3gmddqn933tdukirm7dfujn6lglcfa5vqctdf6uivsihe",
                "SCv7_32_f2e8qjebdo13237siue8id3uohorhkhvt0bi0rdkha23g07d072bvoutdkln3aq6hqehiuv6i7jcn61uouuqeverklsnptvjouccfrcquo4l1aggg0geok000qah47cdh8oi8e4b2k74do5hb36bg2elk8ne9bd8e52r1r6k4jmt5ltlbs7fqt1q3j7t764emuv091bncrroo5d5baue36e34gj35f19qgs19j8d1d3s4fra6n7u55gb5lej7vngve9sgmbaunh2r3sbou2mdmliaqrkqcq5vonkgtdd6sr3qns5r55ko",
                "SCv7_32_f2e8qjq11813237s9f7hd9j9ier5tt87npg63iqi207utqi1u7nqcn8noi9o8d4tchj457j6nbbf2l0vonmf7jiculf2thpqqlijcuv3m8oe08qhu98j5eu06687f03op67432618m880v92uq46gcr81nt6615700548nofmcprfeas1vinofgciuootgqir8hdgd98a97vo4ahab7uvnlavlrdg65v9ij8ch9ccup7km3fpa3ud99hjjc09cginapmoimn0hknbn36ujcq0ghtb20gljfb1ll4aimm",
                "SCv7_32_f2e6qji11b13047s9f70qj1mjd6tlavuo0bh86ia80ub9lc3sbfsrdhaa8i917cpjn4u8oe6l46aesmfkplhmcsmbev1piqoircn91hti80a014a3oe080j2v026b5e42h4lpomm0si20lk9reka3g6lt4898i7glhlphhisssu1rsnpfjk2ugopv8imm49clg9rqo83hdqrsjm73dvsunv42l4a8rq0ksodjnsolbp0tr6fv9061dk1qpndkub5ifled8rcoovnhrbjjol4lug7udu02dvi93v0",
                "SCv7_32_f2e6qjub1b13047siue0qj3mmf4qclvt0evq1k2g0bh43ao7olvnempc2m8ma9spr6cjp7jeniqe3m0uqlqmbpu6eqnuegorrdq7b78j828hj9048q168s1e8b80g8362nhs52caopg5soe369jglhp0p042lh49gd8b525qjmtlrqr5bt7qevbv3rdd0jrlno45si5tijke30oqj28d7cmqhqosk4n24ainbti5oge76i1u0sm27vfidl2v1elha343lbfmjv6fpc0lvubvqr39n3bhnbib90d0",
                "SCv7_32_f2e6b3idhb1j0345tvh7a0mfh9veorhr6vk0i2hho58bkq1rmeca2tovpd6miigh7iiffqapvo5sn9eegvt5nghe1tgqifv5vhapeulrgpeg0o1p86cjbhc9ma4i3apg48p3nl16a0o0o84r39lrr0mo426k84ri8dubnm8mgro7qbcnfksprtm7udeefotdv2goh4bpjhs49bq8dfpli6q4jat3skhdtg34jqh3utapua55csn3k4d1a64dunjtkhbda9ojua89jtnesktn2dadjf7v16nf8s8etvvg0t55g",
                "SCv7_32_f2e6aji11b1j037r9f72ma2etgtbqrhvr05gc395a1t6heot6rrfe9ed1a2sc0e92q9fqce3jjt7mui7qe2om6ei5d7bed54ekopq0ck0mo2qr060ktkcuaasaaho1r95k23cap01cb850pa20e21757t82it20br0d76cef4n7dee4eqv3t99vum73b52099nvbab1l9hdaj8sabodv31fd1ardscj5pljpssfnju5qj1m97v61v0jathskspag1m9aqe6smdrobue3jah5crfjj7ngvh479ai0",
                "SCv7_32_f2e5qjidp913235s9fbhc9j9jar6tt86jp07hpah20bvsbcktvn5vujs2mac1434iacnjefpqaj46uqmmsmhmdtn8suuvmusdpbret8g8h854g59us0ti5ga28o6ii9hcg8i6e8n2000lgnfqev8p1i2j95hfc2952s8reqvtdilejt7rnojpdf9f2ltqa1i7hu68cacj8upcik9nn5bmdp78cavic33kagbr3ts628n9vfu5r5r2nken6hpkjn1thpvipdg7a3s4ip2im8slln69fu67k15gr60g3fnus7rkcqbkk",
            ]
        ),
        (
            .xyzWing,
            [
                "SCv7_32_f2e7qji91r1i037s1fji06b33e9mnuk3nog54k44ajqt1regl9vquqcq5qbnls08f430udpn3vlb9bensbtdpedpbr57skv7f8tblni109g22l2gm3h9968g6828iakkae48ohl6cg9cor4ukj0iolgq30c2g066cookqclppqeovp9gijems67naeesckr9866e1gbj40ftkpa588hh2rrjmihvsmsc99nvs1skklvm3aqlrfbcui68hjo9916m5h765b0hitbv5vc74mtur3nqjatvm0qjvh48g",
                "SCv7_32_f2e9r3m11b1j0246rsiue1mk31hnlreuc17j0q18g7947mvdm2onf7v9oq73mb42v2dkuvovdpdemu5euvhfln5pl7fckslaafejflpro06eq9agg2e00gijdiqmkj41b0oef029k8p0isa61kku4gaj23553r2nv5c642itsun5mmc76b7s6p8ptdsdiipjhbhc30hif59fb29slcbra5lnchau10s8u1na6p9k7a4gujeroi3vgdsgv5mofsgj1fh0j3gjl6cullul7lfifj27mc",
                "SCv7_32_f2e5aji91r13037s9f78rp1cbr96nu815t06kl25l8s41o80sbntg50aohomp3q76esrnqekopurmleniv74rraqhutjddf5tht9e0g3813c2ghc3494hj0982ji0mn1mkn95d12623058jri840i3cbp981t9o0eqpenn75bh7k77f7s5o1pmrob2l1j0dn80j4voihqrojvq4tdei6ptrn3t1d895f9ojab7f9l3e9fgjfiknrdd8o7teth84g6sc4nl2nbqbcptmj1u5k0v115ua4r32pf7nf213vad4p8",
                "SCv7_32_f2e5qjqb1913235s9fbhc9j9rbbrhl8rf01e35a785efgmp8rrev8vfs6m8789kj1hsrhoakvderq5tnqqahnqld3irnba4nmddjn0i208802oe4k0a246hpnq04sa439gg1leqem93e455494p053p2kp8il500eklnefcnqej1o3krvmoqvvfuaad12v68r5dmdu0m4bsomqb8c7ohb979pmr2o44vs49r33qmpnc1lq9j6dvtnim0uapukfq8n7ij88cuqksojlpks6imfln6cdr3p3pchfmm5eu1i1trs00ut566o",
                "SCv7_32_f2e9qjdr1r13037siv68rp37s9q8afv01cl3bah2akeq0c40v1rlo1482luc77afevr2qj676ofdldc6npq62qknnbmdnl6mafk06905c0065io47o5fgp70ii5h2akbl7s84l4gn245kjkpicjtpk32p0i2j4t0stciqt71filcenctsver133d3jbbkfaim840s549kidks0hfum3a4h3jp8ku5pjv79n1gg349ooo7tpjfmqvt0ao4iptu3k5vc1p1ha748",
                "SCv7_32_f2e8qjmbdo1i237s2v76nie6v10qtq8vug5i4baq46mn4i6i3pdfbnrb6r4ilhs00v337hn66smpefjvuqfpc3jl995vurn7huvf9mpl3k98sleh15ls1445i4eaamgphq8amr9lgk20jhagf4s02dji6smp99bi4kbf74hl9nkunmheourathujf7nf7qemoqg5o2gg5486ec45j80k2f8e0gntnt901toieusei0hho95q90nbn2i0am0q7bu6hjgpgfsta4dovt4uj7ihf7dn10fdu6e0utrvluo7l4akiug",
                "SCv7_32_f2eaqk1r1r1j025thfji0odg05jmqrug2d28k5aph8p28qc7aqunnicg9oeim4727n2efs8aqfdccmrrqr89ebictl8peqsrrav8afioqpc2848b4t92mee68a4r72khcqr29c94c7jh3ca4acgkt68t8j6ohrko1qi9skq1or88buqmqt5prpubm266q77mf8m45u5vi4gfh28gj5vde4as10o9r15b08t3ncuqmt244o25o1vn281520soep7jd0cds7o4ah3ei",
                "SCv7_32_f2e7aja91r1j027shf7k3gmoc2e6nuk3nog55b68aaa47egsbbquvhdde9kaau04gq0m37jerrl79bkfsbtdpedprr5nlajjnlf5prog2k8pj40hp7521m0uveiekgqc4jcida4igd7t41i14eii1nlm36pl5o4oogrl3dgbo5qusth9rd89cp8oqukktotl6ghh4i44g28300i5u0sk4qspqipb0m78gvom2pohtjhip7smicq1q7k2j86a5vmh2avn315fqlnfg2tftkf5n489upm71bpnk5f4iq0",
            ]
        ),
        (
            .wWing,
            [
                "SCv7_32_f2e6qja11r12047s1fjjd6atio2nll8vv01974k6kjkk3ao7hlvhek3r636o9mb1cob9splqsjop87u91ioj6ktukviph9tsbr6m0906g0aco2i10i0ip82smgnlea10looo086mie5qo6g8m0m3suh614irejkkfm468ejjnejcm8edufgrp33p7inqivk4np1d14s64pvr7agmm5m2shut287bv7mgoumsp9e759mmvaqnerihjrtb48dnk6vpbfdoe4r9csnp73fuc1f6u3q193t0",
                "SCv7_32_f2e6ajmb1q1i047s2v794b0btj1mnuo7vk11729164fd9tmgkrvlsk0fkpjcgp46r4evh631prui7fsjd6qj2gruknkpt1ts5qj3bga5uq14k00gjjte5511g85s405erjhcdg2qh301elddacn15ha38hbk4p8k188s0d76n6ifj5m6u7b4qvfencqtb1u0vq1s88k1uls8rdngk0eht0j5omh5h0il7bb24rapd69br43h3t3qj6d7cdgufjb22jlq8lk4aeuqfkq7sghcss7lj3ngu76797dg",
                "SCv7_32_f2e7aji11b1j037r9f71qa4escibqrhvr05gk395a1tdhegt6rrfeebdt5gma60bb65arf6de0lvrddsm9kl6os6ub6d798ccmv9nlm08b0712g878o44p779695b1o222gm5d52ep2601t53im9fq1805i3ih1f78j543t6667nnfktucs9tet95tujfpoqsimpos7ipi5438l2in57jldtd39ute9aaalc5cemgvccsuapj3n17vsoun915e2itgftg0gegtkurvr5itqkbsvp08sr8ie6",
                "SCv7_32_f2e6ajq91r13037s9f75hsgm4vigkfv00l48rai82k3rc0s8nvhr81aki5omopps9qe6e66emkvt8ho9rdn171jq5ujnq7fauk9bc09d4el31ukagbch5ej78fp8h3eeqpldc90sln9pp10kkepp8129qi5hqms7896hqdn1eokuen8povev3l6nvps2rrd1l03eg821612pg4al46904otjh7ot772pc9c6jrf7d7kv7j6qcq49o9qlm863s4nocujbepj8bodfvg8brsd27me29bv8p8eeq6l9f15vq4nndgvgf81m3kacgs",
                "SCv7_32_f2e5qjih1q1i035t1ffpl56i2rodfnb04so9260ise3rkvbcr7egee57i63dfpltnqr6udecm6vselqghmnt844vc6tca8dehdl98q7ksgm1mc5c2449o0pi1g41kh430sg0n73o23hn6iifcf9c145npi2j13h8v70mm52ll73h5phmhhhtmjbttitjbp25a1fk7q58mn3o8r75kae7j3c58b4pgemgn6msep11rm84atllviu8o6ddn0p2bvsjd6fr7ofp50lemdobvm3uq2sejh17rfjdpl5b2",
                "SCv7_32_f2e8b3ibd81j2346tvh7a14ilibr6jbfq09g9hgcgq84ankbirfbr6h99kg5jh02tfuvruheudkkp7v3lebmrmskf7eflsb3pjhn4bmrqb1ajcka45ah8r4e53d30nsl3944np6a6n5ogp4d2uns3p5dj956q9iao6n2tgcmodil7bn7frdfbgr1msvksouqbvt2517gdgbamqsm3v3lv4k8vst84i201k0g7llolumv7pgcf4rqg6p8r6uli6e1au07l07r8dmg2ofe4j6e9pcmut38jp0k4gkjvfu8u54dq",
                "SCv7_32_f2e4qji9ho1i237s1fjkcakce7dripju60nohl58gkaeb47di0k7u7t036imb6d2nhafjremddcntipbne1kqrhdptufiabbn7ftpgdhd0060g4239c10oe2ahlj69t3418hao283cp429b8gi14a923d36likkt2uqg0dtposmlv3vpfgv9sbibb57ffn4cs2rgh8ir8pl8pod5c5jgqpd0urrnu2suahtusqvr13m46lokhj6itde9u7bpiv527b6ba44lotnlhj6r24i671tvlg5l1fb0ct4n17pvqdrklh0",
            ]
        ),
        (
            .swordfish,
            [
                "SCv7_32_f2e5qji11q1j037r9f74oimqi8ilpm8fuo128aik15og1dm3krunqrap056msle7e6erooco8dvgubofhlb31157jtn6227b086i0mi529ice90ma5ll2p24hae1h3aqo52avglldbib2pp89714lkd9r4l884h9ma2gk7kbjtdjv3jd6vqq3rqmjs392d8nc9rs2217v4grf585r49eunnjpte48ktk7nh8gcfpvjhm8bujmoil554sfgsmukt8lgjsf2n79r5dlfm2ss5n0liagg",
                "SCv7_32_f2e5qjab1a1j045t9fb0cniccop73muuk0jh030i20bmler8t7epmh2aln68vtoprp5oqioqdrkhil8n38qqchssltkkpmta792lcf30g3g5g32p411rcbg814gr0ht1lj5ll023d34nki55i06vj3ds62m1acj002l53tpl5qbjgjcnfofd5k3fm4243rq5grlk0ivdvspbdb83pmdfamft69mlrbb674dglge7os53ovmm7mtlotqa72hdr5bjhg9srh7avk0lh5a6ds",
                "SCv7_32_f2e5qjmb1a1j047siue1a9m97o9avtgfv82o4g82sb0js3hdvnrsdllmaq35j1mprncrr6r1pruj3nsid5h6b1js9n9i23vpfgp8q4a4186bap71k851hb2m7g0js2lb0e5b9kcjm8k32b00ot5bst40518bc85vr0a4n459pjip9phmhlhtmjbttqtn6mgek6rathkahlq44evd0jqhdaleao4nv7n3u3h7mulvu50visddnhpdul9dnq36vvhfd6lqgc5cd45pcofjf014raq9qk",
                "SCv7_32_f2e5qjab1q1i045t1dlki7hg1jgbdfa19tg24c94oq2tkbmqujn1r3emqoo63pmdvf64mtb3d5nub6aljkldb5a73qnaaavjkhl8b06842bm48lo0231761cca80av0cgo0gt5528vo120gj14hkddih2pm6j795p20q0ajljvp7hibtftkoddlkpme9egtck5ep8joqllmnu6qsp6pu4hrath98f3dlo5fst5utgo1k6urbmkjjs7vncp3om027s977h8mlkff1ult48p2g",
                "SCv7_32_f2e5aji91r1i037s1fji03e60696nus3nog54k442jip191tmjlduqs2m9a60cr3hv3npl1gkvv93nihml6qb1nkhb9jq3b9blaan70534g71041clp1th62hl2grcg29lg86g5gi0do8co8jjal5910cm08qu3g43flgld9ss9eemosotdjftd9tvb9g5q18cdpectkuei6mpitb10ifnokbhf6vn8mavitt4peb3bts7aj7cn7msheimmfntpahbh58sljrce21vpi8ufbitkreeghptft0685iisf",
                "SCv7_32_f2e6qji91r13037s9f78qp5rm7hv82hvs02kh3da91agurf103heve20k4439sh4jronctetb3d47eb4quicktf5ji3nrqea7isscabgg8404gg0p0oiim2oo8015390b1839am5904aq00ij8ickp4tlg4m6p654i0mkltpqeacenfevfen2q2bfeef7cg87il0e0o54de8gq0l3rd0l4idg87l5joorprf1dmnrqilqf07u72avmchph9kvqappdj2iv66idn6t05vrunl6vn0dprpjaq7tg",
                "SCv7_32_f2e5r3ib18132346tv9bb1dvd4j4rn7a1ku82c355240mnobomttmmj733i6vsvs8bp75kt5hi3v5j3edcdjf5a77rnsml3eaurna318dg01j04q812o28dg4mo2cgi4tf03gaci9644k0rbd2m53330ad104l9c80cmtoveqtudjpejd5rjp3r57jf74mo43uhd83qv4chtuv72ls5oiv0gu94np9q4spbcra9t5i5bp16mf28ltr6smva2bckqb8lsgv63hbv1ud5dgqk2qovsprl9ourv01p2mi59",
                "SCv7_32_f2e6qjib1a1j045t9fb0ljp4ppidpmgrug284g82s916q5pdnlth7ol789sm967n95fdsqko8dvgubtf38kt844ufqt8a8dchdl1885gcgcb19j2d0gg42qcsg84mdeoo0se4ihco0qm0b284jtc8cb2552ga7310m8qight2ovrevgsrdnekguvlkv1aqf798l536hk69qerih43vu6fjp99mtqtpak9sjrv08bcb0tcgbvadd6of3qrdonsacbt558lr4j1rjq5auf2stiqig3",
            ]
        ),
        (
            .jellyfish,
            [
                "SCv7_32_f2e5b3ab1b1j0324tvh7a34i5l5kldvd1lt84g2c6222pkmfkainfbss9t4jqm28ud3fdmodefkqvpclrmkmrn2gjpsrl551rhnutp08t98oi421000spc4160mo1j1kq8jd22k8be208qi0b4h2d5c426c00eai4nh1lttosnspphvhrh6nrqdrfen1v0afojfa9lmoanoam66kdbgdkasgqm2ep4rgtkm2a4kmjio6s6ulhnm46itm2rue5bvh82r5p7r01svhjpv3hhgiviq7f1ifvmmp66pvd6v37pfg7u2b3s",
                "SCv7_32_f2e5qji1ho13237r9f7l8skjmg4lpo87vc1a9aa6ik80eo7n03hev92to666hle8h4ern3pgbvdf9kve6nmbd6pgmuvnkflkn7eqso8nk002a4pm111h65aahhv59h9b659250ti40ti22d4hqua0941d51024sgbjlc7c09nvbnlmenqdknuf2fdktdsqgfp9d24ok1okme4q5ptvv7n3n8mq8rih2i3bma5q68h92csd3qcddfohmi3bqt9vk62bvpo5nrdhqbpt4prp46pvdt5mmqo1ulnlu2uf2vfjikofo",
                "SCv7_32_f2e6b3eh1r120325vu2mejbe9fbo3bvq0tvc34khgn2fho561sdfvne2j0op2gmbtmsob5srdpsjppr7ea3rgsqjfqiemaaff6ctrg91d8033f07g4qs45h3j98agpq04a8piqhvm0kg7fai1spj2m2co19ootduatojmtsvqfmpgbknsdo1rspo5iknoh5ttp8o6h6mr8t459aad1c3prppgi55fl4l8gejeq3noljadjekrpn890mkacf6559flsptvd069fcqhnhdvtbvpa4vjptnu037nd5ls",
                "SCv7_32_f2e5ajeb1r1i037r2v746si3895avn8vtg5ik5al919gvnf3m1kvufl0jf388i7cr1opspmpq9u4l3r8gpo30itqovqph5jknmcc2a1qo09gm8o85780jpe2065a0o01g7c430u0av8r21k06n1tpip0besvsgmdo7e2ss8rsfsjojnbjjjei6mb45cf4r31amulbnr7uhuotug6muub0vfbsslr77ahtnibqrat4juhvunqbc2dnvajsvo0j4be1s9faja474irbrir8kmpklljf6ug31769fv0",
                "SCv7_32_f2e5r3mh1a1j0325vsisu5iidm9t8lvn0vtg5g920nok3n8u6rreuipr6pqh94ksrdtt6fj1bj970jcf11mqgo2cuss5vkkomoalkg7koj0kjgoo212h26q1te1n48bm2oulmt2dcoatipsvcc2huf530h5ugd7djnl0o5esqqs78scqn9v1tkmgdsojuh461jv1rid52phmnrb4v2jqjelr92varu4oprt63k0o36lrsktobjpgedecoufp93c7i5eitclfmklc1qodj2ekc1o",
                "SCv7_32_f2e6r3m11q1i0346ruimej8agl5bqrjfm0jj148o2bhk3n8ebfretat2poio6k6avubquva16ujfd5ku25l2j82bhss5oksnso4mks28t11ib34290ed1uu0aakml1cga6bmk6446hjsrc8i4ilrag9slsf5m95l0ketl02go1uolop5uruqa6eqqgr76n0qc74mafnr6qaa6atdrmin1slnsughi5qmg9fak6bmbu33ukrdvqp45d9mmsids67srdi133i8fuj31f3gp3mi7gvr0cibgi2j",
                "SCv7_32_f2e6aji91q1j037shf7k9ck3cc15fuk3no08i22588e81tmgl9vqvgsimplapm0jpts9o9ocefmavs8hk2kgm6727l69ee64em0gcii6lie4egc7mkbis2e54ep3tt885drbpcakf7alai1aubd191dl516oh7kh6qki053gbf1dp1jhditqj3rtmu3b820d393mph50r5ok4l6qjgvp2t59dags827jk6h34lehtevnotlftickd7753t1sju8cmbvl176lckvcu40vfkvdr4nft6mhv0mn3c9i2inn",
                "SCv7_32_f2e5b3ut1r120345ru2un48sbagcomrt0efm1ie889hbps7f8bhrnmreq56gg9vdqv906bpnbnd7gr6ft9r7rpt6uqkeegsrrbmuktge27g901200a4qc6m6ihtt4n22sje2mou912oaam1oeaoet605p526nagsegb5ppveqttdjlujd4vpphpm1qrmkhh2sjgl70cnbgq5kdkjsph3pull8bcj5pjf9hkrqo94ps58ufranase0dsb9bot94qf47tc5937te1rvnhdbnjiof6chujgb94g6uj6ckfkrvngua9b9l8g"
            ]
        ),
        (
            .skyscraper,
            [
                "SCv7_32_f2e7aji91r13037s9f78rp1dhr1havm01cl3bah24476o1ogfsjgckdo6hbcdtkc4voi7j576rmtnfc69kcs5n3eums6mstrjj1id00v9h820ue5g20092a56d86vd343vk9f72idscahkp8ioc76on88ch6pia9191rh7nbd5dgv1vdf2edkd2ul9vs8p4h692ko52dka049q21t9k4o7ahoiio46mpdg8r6mnspufq18kevo5digjmjdu2e7ch6mhfsn6pro32vuhqgkb1fb465t0rlak7ss5tge2bk4",
                "SCv7_32_f2e6r3mt1b130345ruite3ieicr6qthrrv02e65chi17hoevgnhbnmredq54ki1op5rkgshnscogvers9ejdb38pucqhrdjppjjp6qcd8m0b48r12k50tc2k1cs6g8fc0580jh0061c8mbgaiq1p00gacsci98dke1igpcphit9jktj9nvnvlgsggvv9pqh16ga67cukft8sj6qmomf8koiq3hog4vlmf3lidp3p8nm1kjpjalso2pf3cg8aibi897rv6ictqn2de5svjog73mllabpng0j1ld5ma",
                "SCv7_32_f2e7r3id19132344tv9bb0b9jcjaqmttg4jh0njp2j28avobomtpmligjo5pn9kgj67ki7re7qqmjlveqmmsnimdtlb8vmpmmv5tjb8ti123j8h89c0jphi9bq2mrkkipg1nhq3a0lv47kfglg0gh0tla5hshabomtpdesptdnle3c6p3ujjdr9fmkngk4l86sv1a14bh74neeok0dpqc53omh5fsgd3l55qaqp0vc7mbp2fjg52abp31jic3tjuoe6eq9l8112ustopr34ttu2vtrsg4vib9dlg",
                "SCv7_32_f2e6r3ib1p122325uv15h4nrb958mkutg4lj0uf4gn23hs1nq2s7fud8e4g8bdlkksbhsrhpilslfrmpln9skbf5iq7tnckkpfcqq7bk68407gc44t5522cck08cg138tki4amolc8i15d3buc4m0ost53228ld0l4kdpiitpvsr9ic7odj7v76bnivu9tkgd3qehtm9l3nnudk85sjvdtfg9j0tng580bq8cb7khoif5hikecd78q6h7r1a6j2qc4r1vmr8mhf1uummpvviv6cn3ueklhte2n4jqnqko560q",
                "SCv7_32_f2e8qjq91r13037s9f749sgi7d7avp87ng0aik8l17qt05ge43v4tml2lbe8g5bf6frcgbunhuirn537ep6jledu7jp70bjtj4jtee0l81h8g1j05a4h3qlj310b89m9qpk15aif1h4obae22m5ahhj230sogkgicl57a3mtp7eqef5mv5r6nbq3auten70n47oe11ecgcvmc63cvlo30mj0ul45ss77kdn7pabsa57r95dshsg8eve3qbvf53tbnt2jqoelc3t93ve3rjtg67fn8ts0",
                "SCv7_32_f2e6qjib1813235t9fbhcnkj6pktrqgd7j0s155140nfob8kttndm6bgi0ghv4nniabrpjbk5nhqjf5ir6jpr6ea6dfosp9auudti6o8p0ko013g2gs6at9ukgk282493kkh8b0k03jg1t8hemjm5i8bm5jo34i3k8l23b0ucpjhtdrs7nif7u9gbj3343nnrg75330miqa6krgmd07duo0m9dc8g3jcrdnnnndfq50d3amc1b0kj3q5mptprbjvm1nkbmho23hlu5dsej0vat75pjjgnhll96e0",
                "SCv7_32_f2e6ajqbd91j235shfbj331uirmmp4orsg282pougq84avkbirfbqsiibj924p54366kdvgcteiiv1vuq71bcrm2r8furf7fdevlrgpmg2lpb90pg1jak03rokl40jel90c0l9l2309li9d1hg8k6pbih69p5jd91bp3ar08jdobvdmblqektev3f7ksnsemgo8i3fk70f12benvgj2f1kobedab4i1mn6ictvat492ufusaii3js9bu4rghugo3665mp8vo6l8dcu8cisp6bvmvcuvcoifctk0evgun6subsiut",
                "SCv7_32_f2e7b3ib18132346tv9ba0rvqcq6jnfa1kuc3g4kk4g2spmkgnhdqjb5fi0dl477vu8v9qm6l47bmuh9dqelerlcstpdhllh3pjretgu4i5c8gao8eh9gfaiu1g52ki88o11gfhh868himeh3p4kpr3jm379ngk82qhcqfespaeuccjdp9vbvq8f8cevkor9gv84bpge1ttlfnvmhtd9lk4imsm6rtkmikm69ua4ecp907pgm7squqtaq92vkm410ki7iv93e4blb7kqnfeg20jk90vg",
            ]
        ),
        (
            .emptyRectangle,
            [
                "SCv7_32_f2e4r3ib1r130324tu97aaqdab3n3m621ks439a6akic90mv0b2drccr09ah8uvsti4v6snjkl7cfuhcdqbjmdun8sshvqisdtbresu43o9344g0ko2bua4v176a1b1t8kv0b9i1n4al2e9056l160qoij0ism85qusvndasurin9mkfsukktotdr0hf8tl8klak94iu41uopf7242h52lsppre17v9dhnvdts236dsrca7ohqqp6m0mcpchf1dd8epebq2pn5m3os9g8al5g6lnj6r22chdrvals2lbd9ell8k0rjtg741f9m90",
                "SCv7_32_f2e5ajmb1r12047s2v72a6b0b70qnvk1bv8a991164f6ptd0u7ftqrfhq489d7ctjkcpsplsqrgl87u5thpmfhjq5ubm67fb7icrq0brgu6104803seq0lrq5k611o0s8m047hge5506gmd4lhnm0kciptle2p25sqj37dt9bg7uav1uuibq23ntbgqchrtsolp448l9caua0tee0idt05k8p5j5tupfk4l2b24j9m0ma4gt5vpm88pdhq11bocridddc1rt6hk0lptsik2vsqemjjgcb3eirtnrfv5mmphlsrqost6mg",
                "SCv7_32_f2e6ajib1o12235t1fli2uck0b2qrnm02ec0p6cg30bvs5gqttn425l3grqbbrqjs1kpcsstuvql3j169tjajtrirbaqanhfcphm42huieo67u44j0km8k384g1aq00l38ta8dhb80q8921kkg8aahsgagrp7eatp9sln3m7tngj9lvpe0muq8eovt1k3fhqfrc6l2mhua3nh415q61eb3u5hah46khhosf75o4emppq57jb5f1hvqekbkcklesvr2tdc7erikl65f8nplpvvibgr2udt3gs9bfg",
                "SCv7_32_f2e5qjmbh81j237riue1n40tou9v9mntgfuo5gk44587lq7bq2pfvfnmci38b38fm5i4jth75irjsvvnes5seug89dvrbqqnbvte67ke07898096g8vmv4d9094p835ik051f7bak9m57409a0pnm9o9nbt740e47odocgrorrdurl1eiv9viennv7u6hfh82m4piiu4b8i14iul1niq8di32h4f8ju5p34g0ldmpqmpnjbgcb2bqa3p0jlphvv9vqbofaskp29uesbh9o68vv6t7e97erj4jd7u2hqhcq5thh3uoqtcp6b9t3ult14vbutq0jh6",
                "SCv7_32_f2e9aji1d81j237shf7h3335r6b76jbvq0bg9lhcgq8474nmq39bultid4gseu44kkckj35uodv1nmvrv3le3m0ec4fpvvfq6rrf3e47cf4aho462gduo2e06dg385idhklp1e29pkd8nvahhf8tl151nq8ufkjv1m247u5ouvdqinpekvpna6urv78tq264ik4p8674q2akobk5la89go09qj5aplp4lfnkh71366kp7h0kdcgjogek0cnm16f9ug1hanaign5usl2dihqofv0tj6jqutuln3ehecs7jtfvjnabsg",
                "SCv7_32_f2e7ajibdp1i235s1fli13cd6686quk3jogd4gqf918hcieq8mltpf9mlsnrmo7sidjupu8dtdmip7v3ku3m6es4eluffqu7b33u67keg4c4i1a008l1h0had3b869anjfd2n554d7jal3djps4q0cmhuratnpj4bd1gh1vgennrektvbh7efqpiirpq7up18h22q71hlkr8r3bb4jqos6m7iba2mta45rai5cqctib7roj8gpishvsupn4bh1bon8kotrsdsqajqpshv2999cqnvfl1qa0uibkp7ae236dtt7dirnhs9ofp0t3b4j8h",
                "SCv7_32_f2e7aji91r1i037s1fjk9ckd069mnuk3nog54k442jip191tmjlduqtil6bo5s1mcdjdspkoedvsvbr4j9c9i89vqdqcmgqu2v9hht04dg2q52u11cp5ioab26r17b83080gmgmqdkqilpk3gar79480gea4t0un9ij353p5plmhlhtmjftdotrb591515sbfr7rvldvbcc48vjrdaphc7ep2daf2gj1lt8slg7i6knm9hc2bgpcgv3sl6kepd9e41peq3gvdqhrmgoqt4q02ih3l1cnc5gs1fdfng5r07pvi0jbmt5v0",
                "SCv7_32_f2e5ajib1913235s9fbgdkhk9l9beug39sgbpsh8h05nu2u5nedigjphk7ssoj4o7r97o6mjdre7mmlnamdcfb8vmthht5rjb8ji3p521khi96rqaemcqkehhi2notsijbal0636ol7mgtcim4l724qn62d685t5amt9tur9qc7ofjfu726mivv9c6280g1dt8jm73inomg55t0vis4ph0a48brqtu1nn712bkedc4iigdamc98fk688209e8ojf1s272vlpc746gk04ajelk1dcu3rj5c3vndilvc7ou29c5ph6iaf2u44l9kkg",
            ]
        ),
        (
            .twoStringKite,
            [
                "SCv7_32_f2e7ajib1o13225t9fbp4k0aihoqmdvg0gjd6j4q30bvs5gqtsnagoqchgiibf67sf0iqjc77pnfldd5smo4gktvmjurkjvteh6cn14lq6fi25m5d80ook6g84er548m2p90mja5ip9a7rr420s9hk8g1l2sr3kssaq4hpr37emdkrlnrbncefje9smhc29bk13jb47okggcojg8676cqlq65176a5r4fp10knkaf770hvq32j16o7ksovolqvr3ev9708qg0lrst1buhif7ev2mgovc53oe65tprrgfkkv4lfg",
                "SCv7_32_f2e6ajqbd81j235thfbh3q37b773dfa19s81gcoo88b4jmi59fnlsqeqd45kbhiffofgjfsnukr9fpvp6r5b27ua79fsftb9lrpn2bu7ka68h0mlq4lkcbodkk3oa8ag49dqu5i8rai6mcie2mdjksnd26p4cnao751raecm8dsrj3urd5e2t9vjemcsnu9he88g40g989sc0d2vr4ipkragnf3erfpsdk244tqg698fbnaai8kask0dggcbhs96fgalm3498gpvvgq6hi1o5u34hjffrd4b7s9rstvsluoblpupfniu64r2uh5ba",
                "SCv7_32_f2e5qji91r13037s9f7496molrln118vu01a8hil4j283r80sbnjh1a28km2ftkccue4e62fencdauo9teu0kottinhrd3nle87eng4i5k0o8bh96bu5gjoc0lpesmgb8pp013ak8fj487e875hl3t4s78asm96ea79oeldojr5mikoegv6vse6kc5viir8hs8ebsa0ih5blifog9ks979q6t8kp5vf6onu652e9co1p3a1m7ni5tmisj3kc7ehiunn64rass2kv559dfrouq4hfq12vq7pj4vnl444u5ss5miid",
                "SCv7_32_f2e5qjmd1r12033u2v795d55a3c7bfk19uo68p1164tsp7s3oprret7a86dbdt7rg4vdrcllv7a1tl8dsng9ctlfteoirrbqe61g70e8g04i5q0hp204abpq5egj60r958818a0a53510sicg9a98a8sm9g18hj5e94eto3eiut8rtbs3qjnarnjeimvq8qas30l7iluuu46jru4b8iviggub7gkthug94i56k1mqf3st1g5ralojcb366prrnkdp7225etmgu4dar0imba92vkevv8fufjrvr3rttrnfdoaudvmgl5h4",
                "SCv7_32_f2e5b3a91b1j0325tvh7a0ivu8i6f6uuk0jihh048f42478m5munmpcnig3831lf4vupf6dn6aesmcsr45qmcbkfnifckn3easppg126girs20guc212eq4l0j3jt4id86g90hrk6pd6q7f9032u3g0smnt21aa1la9ejj7tjarj2bubf1cqecitdqshl8f7p1usrbj65udbuoapcva5j77kcasqjp2sldqq71tiuetnt30gr8hvsfe4s7ul2kpotlubait1rp8thtp47mkv3fofa52q9df98udve1roat590",
                "SCv7_32_f2e5r3a91b1j0325tvh7a36vmomcnndm6vk0i0hho48blq5kd3ktqar7k21oafsivq9v8d73n47cfuh8cqbjmcumfcshrqiolsbr6cqp3jss0ac2209mm2e0963ddul2l80aobeaj88n4gg4g893tjkg0gel27ja121ejj7dab7fmcidvfv39l51nub7c27m7uedvp0jrr9vo7bva45khnhim66uk9iulgg3djcul9hvknf78b5hnef19lcapitk4ap95bf7qvllv5rlg7h3k3oronduhu370rjfa1h40157a",
                "SCv7_32_f2e8b3u11b1i0346rv2n718ocdh7lneuc17l1a0kk7qd0thrdjmdqprdevc1h32v4n32vuf3oc677rhfv6f4pasd37p2qjf77ji7acdd04g0g02e3gl7j28s835bb92hkea4e3ku04iakgp2guf86q245kkgk6v7020k9180mi26o6jjbn97oin3f3lacfnnrmd3c8r4ma11cr7kbh78up03gbuirl6au13679f1hfj67rt2nbvcmotcnk79ecmitrim12rso21vj754vird5v5e677hecre9470",
                "SCv7_32_f2e4qjabd91j235shfbh3335fnm6pkorug282pougq84b4jmq79bnlru5t72n8ef92dd2tqodtmnirqv6kecm8dctmpltnuqr8ffes0c82904g0l1p5hi0k88d3qu19el7hm9m4c7m724ec92pre83li99284hou3cmu241utrqndaknpfknoneqe9vd9se8hg90mobj6p84pkj3osdaqpt3h7p9d1esf6vtfv4q9vrti64pnlq9je30secmeclhvq1if0q9na57e0nu5cumar2fccvm5jjnvqfklomsvt4avjsbu3pgmkj79g10",
            ]
        ),
        (
            .finnedXWing,
            [
                "SCv7_32_f2e6ajib1813235t9fbhdkjs7aklnfc14s8ac345c4bfs5kaesrpi8kc911lv4nniablf61edkubapodvep0mkrrqjith9jmne37q0440801iih6ik0jimc5j65800gc1106pg2kmaisdaal0meg76u91oj05tgtpq2lre2vtfil1pvpe1fccdkudvaoqkk6108lbrafta0pifd73jguu9aqakse19i9t81s476ddbmh93e4jnhpuu8krls2br3sq7mjd3nc52jft7h0s9v8okd8bvdjfb9qeplhein25qp6su3v00escip8",
                "SCv7_32_f2e5aji11q1j037r9f7i1e951k6tfr87fc0h45daggs01mr1qfvbtdir34k4lr24h6epe6kn63ec5ktb9ol3b1k7junm236rl8t2b6g1311e6b0p131r9h0g0ulor021g22h6h3ai1rnbn0i1m3id7m5brc05jm675d62ld9vfl9f2svkp5ju3r1t0rpv32gksg47db6isovben139tuhpkcj6fq0q0slfgs92l0kme4amijs7osvmjurk9drtfpbvojmi2f3of37ln5rhtikrigts7gp7aauo",
                "SCv7_32_f2e4qjmbdo13237siue5iqcsr3f2olvq0vug594daq8h01t07mqe5nrbosad1i6mf0u7tv56tn9dfjvuqf97tmd5llvrfsq7rvter6nm9580219h82o45baqs2hegn1cgfli5b6lrail41ka1akcskm06qsdh04p10m50ckuerkunmhegtr3k7cesuqqvhqrud1pga2fj1af596c1s306m8l5mmk7lh1ne4odk9ca8ms4r2hobgh1ah3jiut804lvj603nvtnvfivf5rccv35h88odfqh3pnmbpamdcfbvhhfprm4nevu034l56ks",
                "SCv7_32_f2e5aji9ho13237s9f748ahrhrhn0pbu60nk1ql82k4n20361ogfsjgspl1dn4itcmbpehqo5tuvjr7n2rr7a5umvress7rttmrmnm074r029g9dakgf7i70p42l8kj5qh2aouegc5agp2b058q1m43lp6c83p9i0hghffletlp6h9ujs5s5tujingqjv148l22i7a93eul1o2p4hb5c9ib4qpaq7017iilb293lm6vbb4j9lgq34ushpkhftf7a3f0sukkfphv4dhp6r55fufuqm9mtqlo8v521scejtscm7vua22f2u3ad9kgg",
                "SCv7_32_f2e6qjeb1o13227siuf6qgk1mrg5bvu05sodipmjohsf0tegv3no5qte3o68230c6fpghot91utnsrr1lmlj1tir7dnfnm1fsuo0sig0a00h0ck0kb0mk60oi87komm0k5gjuevf5fba4gks2cjsim20g4q76jfm29be2ujekt6jm71mvfht11vtklsh0h4894h22hhdgp8mo8a7ggfgt2tf8oavccvj8894kp070bhb7oirdsl9k95jhj9uom2okaukqgcavrm97cmvubdnasa1677v8tfqbt9tcrv2aif6c7cu5tlaijae",
                "SCv7_32_f2e6ajubhb1j037s2ufmm62pm8mffmntgfuo4gic62a1tuhqmjmbvbssi3m6299c0r6kgorto9uenkrnfurn1b4763rlferuumsjvrn130k1a23060b2844gmkdb3564u238e5h85ks1im71v9d95ehmhdicc4iasplik40es5smvdqjnde4tpvbqijv78od4f292fhhdb8kgm2g9pombd0caiof3avifvj69487akel85o9n6c689pn3fpvtq10v9okn5r5esh5rkcv8t9djqsm58v5odfqb58s9v3ni56nf6mkvi6g3skdljgue5vj3l6t6",
                "SCv7_32_f2e6aji1do1j227shf7k20kc6773bva1bs86jbclkkk8e97d458vs7motmlaiqkc7kphtg4f6hfsdt1ptouurmpepnhrn7pvoou6tltk9vkam82arhomch0mkdeb28aq8lmo9fkb97jb1k527f41kk0qe4mmlm8bkkci39qtvatfdit1jt78forp3b9v3lj3i0a064c3986aaah0a1j60ha7l8gcd7g86nlrvpr6q11fj3c5a9a2pl6hl9nrpscr74c7mmomouajffrraufj0ghm0597irq3unnsodcocmdvvkptnqc9sbqe2t69m",
                "SCv7_32_f2e6r3idd81j2345tvh7a36fm9veor6j3fq0909hgcgm94d4bmqe9rklosi6r84mgnqf8mcmnr1nlqebffvmkoavetgur7vdvjbdevlrgpuk05j8l82fh5css359han4485c1g04up222647nme14l0sig6f3dm2d4028ci8r22ouqtr3jdeit1ojqbrs73fdk6258o8mte7h2u329pr8jcriovs9ts9gjp7ptra8aqbj6dq4aelrinscjtc550h5c84n7blk73pogfuhcppvsu5mtte9bjcvoovd7fcmu771vo1v6j4rtg",
            ]
        ),
        (
            .finnedSwordfish,
            [
                "SCv7_32_f2e7qjibd91j235shfbj3334b6rb6jbfq09g97jp3111cieq8l1esnn9nnbcm8i6ru8kdbtgrr3f4ecu7kedm8dcsetlufu678ffes0c821g015038a11tc2i6q6c2pda49aclljip30bi2i37cogi3cng2durmkoibq1o8gnrnfqtnaiv5uiv2topp7st0n98dcj028pluu365ab31bbhhpac8sm41jmdblj8qk9focmst8c0hi5vgph56fv7spcjgljrfaqqqphakqr2nc9spj8hkvt07ls0pikelnglis6vk7qhte3v83db74qsg",
                "SCv7_32_f2e6qji91r1j027shf7r3161eqgdftg7fl0q8m4hkkk8erk7arunm8bhqgf2k10qgq0u3pd69cesvtaprh0jkdul8tckstdamuljme018p44004p4jq9065kmlf1gusij11j4gh9m4qcgelm4lcj384iig27lijqpdqusvhdithpjpv3m267a73eom6c11so7lkb15a0ao8lhkrvkcqulmf4kg652rkst7gkuc3egk87r33q6fhnchphcc9gagcvim56rc2rc1ngo9mu3s5ad3eromo1mrjr5ftfq8dgfdvg1slu9ei0",
                "SCv7_32_f2e6qjmh1b13037sisv5ne56dndeolfvo0nhhb4cgbsb0j8v2jvtrhk92ea894lrbjn7kdv3ai3m7f8lqf4st37lbb78eemmckr9r09gg0a1q8m4g51ndi4h85fc90qjbf3ag4gf94ks6ifk1mt9hgcio0i2id70mc50ao5j6ebrij7re8teruvja23nsa8q8io5l51de6o99m5egghnrv0ajmjjfnf621vad5u3598geim1u93be272emrhq45udtdnun79jth2mjelfuunabjbihsjo0cftd3si",
                "SCv7_32_f2e6r3id1o122345tv15l4q7bccekljfs04kp1ic9260nvom3bnmtqucl0ot4g6bovlq7tpg3hdrurdn39bbk223nfbc79gdtlu0lao0a3n3ghb5oh25k14q225h1m0225ck2i4t8bmakc6oo4bkml7itht0e2hjga24be4st9olrtvrunnd1drueunfs4blmjq8r7pgiuvverpuqpec8jg1pgjlmhcjcb64pcsud7699ii4j7pt8osjv95ijlh59ckuc9v5mkvh6e15j1h0d57745e4hqk4rpu3ch3o7g0pdm2df0",
                "SCv7_32_f2e6qji1d81j237shf7j3334b6b74jbvq0bg9lhcgq8474nmq39bulsri1eg5cegf2mf2u7sjfjcn61uot7kuuuvklsnptvjouccfrcquo4ls2o91ioppb821gqaq3lhorh8bak23iqk280lchke229820jgkmrjk0n2q573mh5lvlru77qd7qbg7h7m6emuv8949jgpdekgak713hktib6r4ql8d821b0ilkls1i3flbovdon2m8atudbqe118v52duefggpdm4uefmv1dt758mfpf5qjnng3qfe3tgb1530",
                "SCv7_32_f2e5aji91o14227s9efur95036ibrqgffi0sit16jkc0urg7hlvrf6e54kai0g0lqgpgppuqtvlq712dbq2q3nmbd5boeultgh6g1egcaogl2dg22a80iagcd03n01h10fa1j54p418b9udsq6r58qsdmgdh0igpc4amt5rirqbe6sbr73qrafqshcvkl6d30sd2hqaovt0ola3bcts5se546rnp6ib4jctfsofgl2cjlqjohjsq5i77nalhf5j5psl1d1951bma76du9ne5v7puetvgt8e5r7bnn6s5qsdl94qd8o",
                "SCv7_32_f2e6qjqb1813235t9fbhcnmjkj9n3apnu0206ks6o8o0mvobomtpmj6lgl523p3tiabttnbkljhq3nkarfr1mdulddcvctdasu9tmege00p48apq6016ioos73jd8tokb0g9oon8qm39059a83i7ai2mmvr9jdaf1beccnaesms2nsts3ebb33m3n5c10f3scbr83f340cdb8kngq8iiv92cpr3c0qh4lfo7l4qf89nsr9l9l64pnovrgl47vc25bfbavau3fd7t69d46nqpbnaeoojqsibdc4pumcnr0gknd3p7glu4rvo",
                "SCv7_32_f2e7r3ibd81j2346tvh7a13qhli6f6usk0jgh30p1ggonf0m5msnmp2f7betaglv5lurv43vq9p6rsqnven6inrmd5ksuuhpmqitqrr9jv870fasn95a8arifv9l8eglaj796k1hesoit2k4iqsh1ok42dsop1lbl1cd8j39isfbeuhtqjpvis5qphmjtnbbbv2ad0101950gagckoctg6282ne3jo4ai43tdg1ok0oc4emtds5sqelcdocgpso0q74fkk8u9q2fv0rjrrq3ei3cli6bsrlmp37vfui2evduovpbkd5audr81h6lc",
            ]
        ),
        (
            .finnedJellyfish,
            [
                "SCv7_32_f2e6qjmb1o13227siuf6qcl52hrbrqgvv02idmrcj8c0vfge3bvlrc5ebpm06j4ppr027j576rmtlfc6ums0kstrqnhrdjfde87em001698ccnl0uqr26ea10555jg646aa32pdl4q5o42g8b58s8136i162nm9tig8ldobqlqjkqf8s6rtu7l56vmivk82ihq42j4o51i8ok1a5ost4gl0p1ias8ro6jvm1php4koa8tgnod868jpo17mbdmvfursfrf82uflvdvabrafomttm9pjflrl6ojt1vvcrcs6as5so52kp4rr0",
                "SCv7_32_f2e6qjmb1b1j037riue5mk0sot4nnrfuc1fl0q18g79c7lndm2onv7vrki663235p65fadnt5lrtfv2akqn0lkv7csd2veefqfet91mo0ls1n080pfo8tb07s1cdi2474322p12pest04771ologol3p3fj5r43i0hb2hg8kspokvdp61l1t73ittrd2jjc7a2neb0ssa28aga1qbacbroso6h1kjsnbumb8vtqsjqst896rlutrstl52rr9vrvglfhbg56chepefn1igar0n1uvfiv4alqak8",
                "SCv7_32_f2e5ak6b1b13047siue0qj3n6unltt8fvi144go9h23rcuigvhrp6d2qcnctep370rp59kssoppnkh6lgu1plkhtbp7miinbk9t0a2630m1t00b4jj01i20202r2slo447oo2o8sn980tg40tcp9sc83ei7aab45i8bnak5n4n7ceu5p3i3un666c66sb209j8m782bbukrbhli8ivjkuc7p1mr7b8aqdl7d3j6ihok909nfmcjdbh2v6i3qvk965cqjvkse6p2rmtvbftkbmh7u4f6odqi94elde6tgs95lo",
                "SCv7_32_f2e6r3eh1b130325vuisu5jemam4qv6l7vo0m1hbkcg3te79gfhbvmrdd8au8skrmgssrfdrs6efmgtu4mrrb38ru8qprtjpp39uhdme01o270e04g40c5a0p4h9e0accagd46b9762o96ugd8qd0j5h0l30ppatcuc434786rn359nj5oeoveveqjjrt6ui3g2dva3oarqh9o5b53kaemtbnin91h8l5m1h5ufhpsbe7havl30fv4ukm0d3rardqvnqqi253dbavbvq8rb0rrnh0h7auie9",
                "SCv7_32_f2e4r3i91q1j0325tu93b49u36e88bdt857o0h4448ghct2omjldqqosd28pau7o5vonvar95nhrbf5it99a79nipj5qaj75fp9pqgngio0485pds00o58e0inippe4fm2bd69l4p2rkqj0hhtur10h5i25i2209ual533qrbrtjpjvtm266a77ef5du8mt7m63o3tjdqjffshp42f7cts91nk8oe6h2d49opl02qlk1j5dm2kf7nhcv7cs6ri4s4jj4t57c6mdstvkf2atbl8mt1sqfqlila2oflb6qa2fiv7at9av0",
                "SCv7_32_f2e5qjq91q1j037s9f7486h71oolpmovug2kgh182bh01d47arunm4sm2qd52omb3q7iebulhmorrhb7a1qlba1e7r1713atjgjlaatelg9hggi9pod80hbs1826e2fp70okt630c28ht09362c2lp1sml0mo5r6sq0l98feacc2v8ff5v6t1hlmj51ls15tgcl772hb99feu3o2tkb8lsv5arp4cutg9or54ahq5na3g8bnevilakdual7udi5hvfrf9n9cjj3skpccvvmaafpe8dcmosrgeg6vbvg0e02ko2o",
                "SCv7_32_f2e5r3id1a230345tu9bbgjb6hmnbqusc1720m5440nd96e51hpveift86a45i6bvfpd4bvlafm9ts8jl2n35qn37e68vm67cmj9k30atfg8b787hckg0ocbo91gq67h02bipmnb822jei2ab6rr4a0slio8t5b5513hjff660qm264qerm65lpe44ek5biohrqprnat972rie3reema929dafnl1rlen6o0f7baeaodeh1onrj1q6cntmabcrfcqjmpfarnspmej6i4nsvvg22br4",
                "SCv7_32_f2e4ajqbdp1i235s1fli138d6q86quk3jogd4gqf918hdu9dbbiutdbp9m16af7mr1hvg3fbckmdvot7gtutn1bl7jtfiqtcsdr0ruq0c0ad816k08i72rrch6h550gqhlbb5saa23b8cu8qanomh7a8d2194903agqupgntr8noevhq3m7eep9cotdvehc82k8r3aatk872qsmtla4akk98dvas91jboivrro87phsilbl5k9njqdpmjhq87t93o8ikfigqr51rdbnsr8uaa6hroe3b5psjmbnkuqjril7rrmk5ejtcpgnj1s0h6itl",
            ]
        ),
    ]

    @Test("Test Hints", arguments: testGrids)
    func testHints(technique: HintTechnique, gridStrings: [String]) async {
        for gridString in gridStrings {
            let state: BoardState

            do {
                state = try BoardStateParser.parse(gridString)
            } catch {
                Issue.record("Failed to parse grid string: \(error)")
                continue
            }

            let hint = HintFinder.findHint(for: technique, in: state)

            // Verify that a hint was found
            #expect(
                hint != nil,
                "Expected \(technique.rawValue) in \(gridString)"
            )

            if let hint = hint {
                // The technique should match
                #expect(hint.technique == technique, "Hint for: \(gridString)")
            }
        }
    }

    @Test(
        "Finned fish hints identify fins and restrict eliminations to the fin box",
        arguments: testGrids.filter {
            [.finnedXWing, .finnedSwordfish, .finnedJellyfish].contains($0.0)
        }
    )
    func testFinnedFishStructure(technique: HintTechnique, gridStrings: [String]) throws {
        for gridString in gridStrings {
            let state = try BoardStateParser.parse(gridString)

            guard let hint = HintFinder.findHint(for: technique, in: state) else {
                Issue.record("Expected \(technique.rawValue) in \(gridString)")
                continue
            }

            // The recorded reasoning must be consistent with the board.
            #expect(
                hint.reasoning.inconsistencies(in: state).isEmpty,
                "\(technique.rawValue) reasoning inconsistent in \(gridString)"
            )

            // All actions must eliminate one single fish digit.
            var eliminationDigits = Set<Int>()
            for action in hint.actions {
                guard case .ruleOut(let digit) = action.action else {
                    Issue.record("\(technique.rawValue) produced a non-elimination action")
                    continue
                }
                eliminationDigits.insert(digit)
                #expect(
                    state.pencilMarks[action.position.row][action.position.column].contains(digit),
                    "Elimination targets a candidate that is not present"
                )
            }
            #expect(
                eliminationDigits.count == 1,
                "\(technique.rawValue) should eliminate exactly one digit, got \(eliminationDigits)"
            )

            // A finned fish must record its fin cells, and every elimination
            // must see the fins (share the fins' box).
            let finCells = hint.reasoning.components
                .filter { $0.role == .fin }
                .flatMap { $0.cells.map(\.position) }
            #expect(
                finCells.isEmpty == false,
                "\(technique.rawValue) should record at least one fin cell"
            )

            if let finBox = finCells.first?.houseNumber {
                #expect(
                    finCells.allSatisfy { $0.houseNumber == finBox },
                    "All fins must share one box"
                )
                for action in hint.actions {
                    #expect(
                        action.position.houseNumber == finBox,
                        "Elimination at \(action.position) does not see the fin box \(finBox)"
                    )
                }
            }
        }
    }

    @Test("Test Hints Empty", arguments: HintTechnique.allCases)
    func testHintsEmpty(technique: HintTechnique) async {
        let grid = Solution.empty()
        let pencilMarks = Validator.validOptions(for: grid)

        let state = BoardState(
            grid: grid,
            pencilMarks: pencilMarks,
            validOptions: pencilMarks
        )

        let hint = HintFinder.findHint(for: technique, in: state)

        // Verify that no hint was found
        #expect(hint == nil)
    }

    // MARK: - Property-Based Tests

    @Test("Hints never create conflicts", arguments: testGrids)
    func testHintsNeverCreateConflicts(technique: HintTechnique, gridStrings: [String]) async {
        for gridString in gridStrings {
            let state: BoardState
            do {
                state = try BoardStateParser.parse(gridString)
            } catch {
                Issue.record("Failed to parse grid string for \(technique.rawValue): \(error)")
                continue
            }

            let hint = HintFinder.findHint(for: technique, in: state)

            if let hint = hint {
                let newState = applyHintToState(hint, state)
                #expect(
                    Validator.hasNoConflicts(in: newState.grid),
                    "Applying \(technique.rawValue) hint created conflict in \(gridString)"
                )
            }
        }
    }

    @Test("Hints always reduce candidates", arguments: testGrids)
    func testHintsAlwaysReduceCandidates(technique: HintTechnique, gridStrings: [String]) async {
        for gridString in gridStrings {
            let state: BoardState
            do {
                state = try BoardStateParser.parse(gridString)
            } catch {
                Issue.record("Failed to parse grid string for \(technique.rawValue): \(error)")
                continue
            }

            let hint = HintFinder.findHint(for: technique, in: state)

            if let hint = hint {
                let originalCount = countCandidates(state)
                let newState = applyHintToState(hint, state)
                let newCount = countCandidates(newState)

                #expect(
                    newCount < originalCount,
                    "\(technique.rawValue) should reduce candidates (was \(originalCount), now \(newCount))"
                )
            }
        }
    }

    @Test("Hints are deterministic", arguments: testGrids)
    func testHintsAreDeterministic(technique: HintTechnique, gridStrings: [String]) async {
        for gridString in gridStrings {
            let state: BoardState
            do {
                state = try BoardStateParser.parse(gridString)
            } catch {
                Issue.record("Failed to parse grid string for \(technique.rawValue): \(error)")
                continue
            }

            let hint1 = HintFinder.findHint(for: technique, in: state)

            let hint2 = HintFinder.findHint(for: technique, in: state)

            // Both should find the same hint or both should find nothing
            if hint1 == nil {
                #expect(hint2 == nil, "Hints should be deterministic")
            } else if let h1 = hint1, let h2 = hint2 {
                #expect(h1.technique == h2.technique)
                #expect(h1.actions.count == h2.actions.count)
                // Note: Don't compare exact actions as Set order may differ
            }
        }
    }

    // MARK: - Solution Verification (False Positive Detection)

    @Test("Hints never eliminate solution digits", arguments: testGrids)
    func testHintsNeverEliminateSolutionDigits(technique: HintTechnique, gridStrings: [String]) {
        for gridString in gridStrings {
            let state: BoardState
            do {
                state = try BoardStateParser.parse(gridString)
            } catch {
                Issue.record("Failed to parse grid for \(technique.rawValue): \(error)")
                continue
            }

            let solveResult = SudokuSolver.solve(grid: state.grid)
            guard let solution = solveResult.solution else {
                Issue.record("Failed to solve grid for \(technique.rawValue): \(gridString.prefix(30))...")
                continue
            }

            guard let hint = HintFinder.findHint(for: technique, in: state) else {
                Issue.record("Expected to find \(technique.rawValue) hint in \(gridString.prefix(30))...")
                continue
            }

            for action in hint.actions {
                let row = action.position.row
                let col = action.position.column
                switch action.action {
                case .ruleOut(let digit):
                    #expect(
                        digit != solution[row][col],
                        "\(technique.rawValue) incorrectly eliminates solution digit \(digit) at (\(row),\(col))"
                    )
                case .solveAs(let digit):
                    #expect(
                        digit == solution[row][col],
                        "\(technique.rawValue) solves (\(row),\(col)) as \(digit) but solution is \(solution[row][col])"
                    )
                case .pencilIn, .clear:
                    break
                }
            }
        }
    }

    // MARK: - Cross-Validation Tests (False Positive Detection)

    @Test("Solved board returns nil for all techniques", arguments: HintTechnique.allCases)
    func testSolvedBoardReturnsNilForAllTechniques(technique: HintTechnique) {
        if technique == .validation || technique == .unknown {
            return
        }

        let solvedGrid = Solution.cells(
            from: "123456789456789123789123456231564897564897231897231564312645978645978312978312645"
        )
        let pencilMarks = Validator.validOptions(for: solvedGrid)
        let state = BoardState(
            grid: solvedGrid,
            pencilMarks: pencilMarks,
            validOptions: pencilMarks
        )

        let hint = HintFinder.findHint(for: technique, in: state)
        #expect(
            hint == nil,
            "\(technique.rawValue) should not find a hint in a solved board"
        )
    }

    // MARK: - All Hints Tests

    struct PuzzleAllHintsTestCase {
        let gridString: String
        let expectedTechniques: Set<HintTechnique>
        let description: String

        init(gridString: String, expectedTechniques: Set<HintTechnique>, description: String = "") {
            self.gridString = gridString
            self.expectedTechniques = expectedTechniques
            self.description = description
        }
    }

    static let allHintsTestCases: [PuzzleAllHintsTestCase] = [
        // Puzzle with basic techniques
        PuzzleAllHintsTestCase(
            gridString:
                "000000000000000000000000000000000000000000283000000154000000000000000070000000090",
            expectedTechniques: [
                .nakedSingle, .nakedTriple, .hiddenPair, .hiddenQuad, .lockedCandidatesPointing,
            ],
            description: "Simple puzzle with naked and hidden singles"
        ),

        // Puzzle with naked pair and many advanced techniques
        PuzzleAllHintsTestCase(
            gridString:
                "658003421249185003713006598802030150037000286005800000586010042971000805324008017",
            expectedTechniques: [
                .nakedPair, .hiddenPair, .xWing, .swordfish, .jellyfish,
                .xyWing, .yWing, .skyscraper, .finnedXWing,
                .lockedCandidatesPointing, .lockedCandidatesClaiming,
            ],
            description: "Complex puzzle with naked pair and many techniques"
        ),

        // Puzzle with X-Wing and advanced techniques
        PuzzleAllHintsTestCase(
            gridString:
                "040070180003100700170948035617890350009000071000701908791486523004017896068009417",
            expectedTechniques: [.xWing, .swordfish],
            description: "Advanced puzzle with X-Wing pattern"
        ),

        // Puzzle with Swordfish and many techniques
        PuzzleAllHintsTestCase(
            gridString:
                "638005219149628000752193800820951030573860901000030508300509602265380190007216000",
            expectedTechniques: [
                .swordfish, .nakedTriple, .hiddenPair,
                .xyWing, .yWing, .xyzWing, .skyscraper,
                .finnedXWing, .finnedSwordfish, .finnedJellyfish,
                .lockedCandidatesPointing, .lockedCandidatesClaiming,
            ],
            description: "Complex puzzle with Swordfish pattern"
        ),

        // Sparse puzzle with hidden singles
        PuzzleAllHintsTestCase(
            gridString:
                "000093000000005000000064000000000000000000000000000000000000000000700000000000000",
            expectedTechniques: [
                .hiddenSingle, .nakedTriple,
                .lockedCandidatesPointing, .lockedCandidatesClaiming,
            ],
            description: "Sparse puzzle with hidden singles"
        ),
    ]

    @Test("Discover all hints in puzzle", arguments: allHintsTestCases)
    func testDiscoverAllHints(testCase: PuzzleAllHintsTestCase) async {
        let grid = Solution.cells(from: testCase.gridString)
        let pencilMarks = Validator.validOptions(for: grid)

        let state = BoardState(
            grid: grid,
            pencilMarks: pencilMarks,
            validOptions: pencilMarks
        )

        var foundTechniques = Set<HintTechnique>()

        // Try to find hints with each technique
        for technique in HintTechnique.allCases {
            if technique == .unknown || technique == .validation {
                continue
            }

            let hint = HintFinder.findHint(for: technique, in: state)
            if hint != nil {
                foundTechniques.insert(technique)
            }
        }

        // Check that we found all expected techniques
        let missingTechniques = testCase.expectedTechniques.subtracting(foundTechniques)

        #expect(
            missingTechniques.isEmpty,
            "[\(testCase.description)] Missing expected techniques: \(missingTechniques.map { $0.rawValue }.joined(separator: ", "))"
        )
    }

    @Test("Find all applicable hints in puzzle", arguments: allHintsTestCases)
    func testFindAllHints(testCase: PuzzleAllHintsTestCase) async {
        let grid = Solution.cells(from: testCase.gridString)
        let pencilMarks = Validator.validOptions(for: grid)

        let state = BoardState(
            grid: grid,
            pencilMarks: pencilMarks,
            validOptions: pencilMarks
        )

        var foundTechniques = Set<HintTechnique>()

        // Try to find hints with each technique
        for technique in HintTechnique.allCases {
            if technique == .unknown || technique == .validation {
                continue
            }

            let hint = HintFinder.findHint(for: technique, in: state)
            if hint != nil {
                foundTechniques.insert(technique)
            }
        }

        // Check that we found all expected techniques
        let missingTechniques = testCase.expectedTechniques.subtracting(foundTechniques)
        let extraTechniques = foundTechniques.subtracting(testCase.expectedTechniques)

        #expect(
            missingTechniques.isEmpty,
            "Missing expected techniques: \(missingTechniques.map { $0.rawValue }.joined(separator: ", "))"
        )

        // Note: Extra techniques are OK - puzzles often have multiple applicable hints
        // We just want to ensure we find at least the expected ones
        if extraTechniques.isEmpty == false {
            // Log extra techniques for information (not a failure)
            // This helps us understand what other hints are available
        }
    }

    // MARK: - Helper Functions

    private func applyHintToState(_ hint: HintStep, _ state: BoardState) -> BoardState {
        var newGrid = state.grid
        var newPencilMarks = state.pencilMarks

        for action in hint.actions {
            switch action.action {
            case .solveAs(let value):
                newGrid[action.position.row][action.position.column] = value
                newPencilMarks[action.position.row][action.position.column] = []
            case .ruleOut(let value):
                newPencilMarks[action.position.row][action.position.column].remove(value)
            case .pencilIn(let value):
                newPencilMarks[action.position.row][action.position.column].insert(value)
            case .clear:
                newPencilMarks[action.position.row][action.position.column] = []
            }
        }

        let newValidOptions = Validator.validOptions(for: newGrid)

        return BoardState(
            grid: newGrid,
            pencilMarks: newPencilMarks,
            validOptions: newValidOptions
        )
    }

    private func countCandidates(_ state: BoardState) -> Int {
        var count = 0
        for row in 0..<9 {
            for col in 0..<9 {
                if state.grid[row][col] == 0 {
                    count += state.pencilMarks[row][col].count
                }
            }
        }
        return count
    }
}
