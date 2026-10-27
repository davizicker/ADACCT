class_name Notas
extends RefCounted
## Textos dos bilhetes, cartas e documentos espalhados pela vila e pelas casas (lore). Edite à vontade.
## O Bradador vem da lenda do corpo que a terra rejeita. Aqui, a culpa é de quem fez o mal (o capataz), nunca das vítimas
## (veja docs/03, docs/04 e docs/10). O jogo se passa em 1961: os textos são de moradores da época
## (docs/08-ambientacao-1961.md). Nomes e fatos são FICÇÃO e precisam de revisão cultural antes de publicar.
## Cada item: [título, texto]. O índice é o `nota_id` do bilhete.

const TEXTOS: Array[Array] = [
	["Bilhete do sineiro",
	"Se ouvir o grito depois da meia-noite, não olhe pro morro.\n\nQuando o grito acabar, AGACHE e fique quieto, parado, sem luz mexendo. O Bradador conta passos e conta olhares. Quem corre ou encara, ele leva.\n\nA chave da igreja eu escondi em casa, dentro da caixa de madeira embaixo da cama."],
	["Carta de Dona Benedita",
	"Tomé, meu filho,\n\nSe você leu o meu recado, é porque chegou. Deixei querosene para a sua lanterna em alguns cantos da rua. A luz da rua cai quase toda noite, você sabe.\n\nE se escutar galope no calçamento, apague a lanterna. A Mula corre atrás da claridade, nunca do escuro. Entre num beco e fique agachado até o fogo passar.\n\nEstou na igreja com o Seu Tobias. Só a porta da frente está trancada, e ele escondeu a chave. Leve também o que a Irmandade precisa: o livro dos Vaz. É por causa dele que a terra grita.\n\nO meu terço está no oratório. Leve também. Deus te guarde."],
	["Da Irmandade do Rosário",
	"Faz mais de setenta anos que acabou o cativeiro, mas a terra não esquece. Cuidamos dos nossos mortos com respeito, na terra consagrada, com reza e com nome.\n\nNão é nenhum de nós que grita nas encostas. É o capataz que a terra recusou, o homem que fez o mal e não achou descanso. O que anda por aí é o castigo dele, não a nossa dor.\n\nEle apagou os nomes dos nossos do livro para que ninguém pudesse rezar por eles. Enquanto os nomes não forem lidos em voz alta na igreja, ele continua gritando."],
	["Anotação do sacristão",
	"O corpo-seco não pisa em chão benzido. Por isso a igreja nunca foi tocada.\n\nQuem chegar até a porta da igreja antes do amanhecer, com a chave e com o livro, a salvo estará. Mas o caminho é longo e ele sabe contar passos.\n\nSó a minha mão e a mão de um filho da Irmandade abrem a porta. Tomé tem o sangue. Falta ele chegar.\n\n— Tobias"],
	["Recado da menina da padaria",
	"Se ele gritar, abaixa e fica parado. Não tosse, não respira alto.\n\nQuem corre faz barulho no chão de pedra, e ele escuta. Passo curto e agachado quase não faz som.\n\nE nunca encare ele. Quem olha demais, ele leva.\n\nO pão de ontem está no cesto. Pode pegar, mas não demora."],
	["Último bilhete",
	"Se você está lendo isto, já passou da ponte e quase chegou.\n\nA igreja está logo acima. Não olhe pra trás.\n\nSe a luz da porta ainda estiver acesa, é porque alguém ficou esperando."],
	["Bilhete do Seu Zé",
	"Dona Benedita me pediu para guardar a chave do Casarão dos Vaz. Disse que um dia o filho dela viria buscar.\n\nEstá na gaveta do balcão. Eu nunca abri aquele casarão desde 1940. Quem entra lá, sai diferente.\n\nSe o rádio chiar sozinho, não ligue de volta."],
	["Livro de Registros dos Vaz",
	"\"Entradas do ano de 1798. Fulgêncio Vaz, capataz.\"\n\nPáginas riscadas com raiva. Onde havia nomes, só tinta preta. Uma folha solta, escrita depois por outra mão: a mão do avô de Dona Benedita, que copiou os nomes de memória antes de o livro ser trancado:\n\nMaria Conga. Antônio Cabinda. Rosa Mina. Domingos Angola. Luzia Benguela. Gaspar Moçambique. Joana Cassanje. Benedito Rebolo.\n\nNo fim, em letra tremida: \"Leiam alto, na igreja, antes do dia. Eles precisam ouvir o próprio nome.\""],
	["Carta do Seu Tobias",
	"Tomé,\n\nSe a casa do sineiro estiver aberta, é porque eu deixei. A chave da igreja está na caixa de madeira embaixo da cama.\n\nEu fico no sino. Se o Bradador chegar perto demais, toco, e ele recua. Mas o sino não aguenta a noite toda. Venha logo.\n\nNunca grite de volta. A gritaria acorda mais do que apazigua. O que ele quer é ser ouvido sem resposta.\n\n— Tobias"],
	["Jornal \"Gazeta da Serra\", março de 1961",
	"\"MINERADORA MANDA FECHAR GALERIAS ANTIGAS. Moradores relatam gritos nas encostas e galope sem cavalo nas noites sem lua. A Prefeitura atribui o barulho aos ventos e pede calma.\n\nNa Rua Direita, cinco lampiões a querosene foram doados pela Irmandade para a iluminação da subida à matriz, já que a rede elétrica cai com frequência.\"\n\n(Recorte guardado pelo barbeiro, com uma cruz desenhada a lápis ao lado.)"],
	["Caderno de fiado da padaria",
	"Dona Benedita ... 3 pães, pagou com reza.\nSeu Zé ... 12 pães, vai pagar no sábado.\nTobias (sineiro) ... leva todo dia às 5h.\n\nAnotado a lápis no fim da página: \"O pão que sobra eu deixo na janela. Quem passa à noite precisa mais.\""],
	["Diário de Tomé (primeira página)",
	"Meu nome é Tomé Aragão, tenho 29 anos. Cheguei à vila de caminhão, com o último frete da tarde. Minha mãe mandou um recado pelo correio: \"Venha antes da lua nova.\" Não escrevo para ela há dois anos.\n\nA vila está sem luz. A subida até a igreja é longa. Preciso encontrá-la."],
	["Bilhete do Seu Mateus (carpinteiro)",
	"Entreguei a escada nova para o sineiro, e ele me pediu um favor estranho: reforçar a porta da torre por dentro. Disse que o sino às vezes toca sozinho depois da meia-noite.\n\nNão cobrei. Dizem que quem ajuda a igreja, a noite poupa."],
	["Caderno de caligrafia, 3º ano",
	"Lição de hoje, copiar dez vezes:\n\n\"Todo nome merece ser dito em voz alta.\"\n\nA professora Lúcia escreveu embaixo, a lápis: \"Principalmente os que o livro apagou.\""],
	["Encomenda do ferreiro",
	"Trinta correntes e uma tranca nova para a porta do porão do Casarão. Pagamento adiantado, em cruzeiros, pelo Dr. Anselmo Vaz.\n\nPediu que ninguém soubesse. Pediu também que eu não perguntasse para quê."],
	["Diário da casa abandonada",
	"Nos fomos embora na terça. A menina não parava de chorar: dizia que alguém gritava o nome dela no meio da noite.\n\nSe você achou isto, não fique. A casa está inteira, mas ela não é mais nossa."],
	["Livro de hóspedes da pensão",
	"12 de março de 1961: Dr. Anselmo Vaz, da Mineradora, quarto 2. Ficou três noites. Perguntou duas vezes pelo Livro de Registros e pela chave da igreja.\n\nDona Elvira anotou: \"Dá gorjeta demais pra quem pergunta de menos.\""],
	["Encomenda do vestido de luto",
	"Dona Benedita encomendou um vestido preto \"para um enterro que ainda não aconteceu\". Pagou com um terço de contas de madeira. Disse que voltava quando a lua estivesse nova.\n\nEu guardei o vestido no armário gótico."],
]
