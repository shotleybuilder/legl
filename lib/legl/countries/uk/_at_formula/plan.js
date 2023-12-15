IF(
    AND(
        OR(Function = "Enacting Maker", Function = "Amending Maker", Function = "Revoking Maker", Function = "Making"),
        OR({ Live?} = "✔ In force", { Live?} = "⭕ Part Revocation / Repeal"),
        Family != BLANK(),
        OR(type_class = "Act", type_class = "Regulation")
    ),
    "PUBLIC",
    IF(
        AND(
            OR(Function = "Enacting Maker", Function = "Amending Maker", Function = "Revoking Maker", Function = "Making"),
            OR({ Live?} = "⚠ Planned", { Live?} = "✔ In force", { Live?} = "⭕ Part Revocation / Repeal"),
            Family != BLANK(),
            OR(type_class = "Act", type_class = "Regulation", type_class = "Order")
        ),
        "STARTER",
        IF(
            AND(
                OR(Function = "Enacting Maker", Function = "Amending Maker", Function = "Revoking Maker", Function = "Making"),
                OR({ Live?} = "⚠ Planned", { Live?} = "✔ In force", { Live?} = "⭕ Part Revocation / Repeal", { Live?} = "❌ Revoked / Repealed / Abolished"),
                Family != BLANK(),
                OR(type_class = "Act", type_class = "Regulation", type_class = "Order")
            ),
            "SUPPORTER",
            "SPONSOR"
        )
    )
)