local DRMCard = require("libdrm.DRMCard")

local card = DRMCard()

for _, con in card:connections() do
	print("Connection:", con)
	if con.Encoder then
		print("\tEncoder:", con.Encoder)

		for k,v in pairs(con.Encoder) do
			print("!!!enc",k,v)
		end
		for k,v in pairs(getmetatable(con.Encoder).__index) do
			print("!!?enc",k,v)
		end

		if con.Encoder.CrtController then
			print("\t\tCrtController:", con.Encoder.CrtController)
		end
	end
	print(("="):rep(80).."\n")
end
